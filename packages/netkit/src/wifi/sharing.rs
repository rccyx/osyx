use anyhow::{Context, Result, bail, ensure};
use ini::{Ini, ParseOption};
use std::{
    fs,
    io::Write,
    path::Path,
    process::{Command, Stdio},
};

const HEX: &[u8; 16] = b"0123456789abcdef";

pub struct Network {
    pub name: String,
    pub security: String,
    pub hidden: bool,
}

#[expect(clippy::print_stdout, reason = "Credentials are CLI output")]
pub fn print(network: &Network) -> Result<()> {
    let password = _password(network, Path::new("/var/lib/iwd"))?;
    let payload = _payload(network, &password);
    let mut renderer = Command::new("qrencode")
        .args(["-t", "ANSIUTF8"])
        .stdin(Stdio::piped())
        .spawn()
        .context("could not execute qrencode; install qrencode with just setup")?;
    let input = renderer
        .stdin
        .take()
        .context("qrencode stdin unavailable")?;
    let written = {
        let mut input = input;
        input.write_all(payload.as_bytes())
    };
    let status = renderer.wait()?;
    written
        .context("could not send Wi-Fi credentials to qrencode")?;
    ensure!(status.success(), "qrencode failed: {status}");
    println!(
        "SSID: {:?}\nSecurity: {}\nPassword: {:?}",
        network.name, network.security, password
    );
    Ok(())
}

fn _password(network: &Network, directory: &Path) -> Result<String> {
    match network.security.as_str() {
        "open" => return Ok(String::new()),
        "psk" => {}
        security => bail!(
            "QR sharing does not support iwd security type {security}; enterprise credentials cannot be shared as a personal Wi-Fi QR code"
        ),
    }
    let path = directory
        .join(format!("{}.psk", _profile_name(&network.name)));
    let content = fs::read_to_string(&path)
        .with_context(|| format!("could not read {}; sharing saved credentials requires permission to read iwd profiles (run netkit qr with sudo)", path.display()))?;
    _passphrase(&content)
}

fn _passphrase(content: &str) -> Result<String> {
    let profile = Ini::load_from_str_opt(
        content,
        ParseOption {
            enabled_quote: false,
            enabled_escape: false,
            ..ParseOption::default()
        },
    )
    .context("invalid iwd profile")?;
    let security = profile
        .section(Some("Security"))
        .context("iwd profile has no Security section")?;
    ensure!(
        security.get("EncryptedSecurity").is_none(),
        "iwd credentials are encrypted; QR sharing requires a readable Passphrase"
    );
    let passphrase = security.get("Passphrase").context("iwd has no saved Passphrase; a derived PreSharedKey cannot recover the original password for phone sharing")?;
    let decoded = _unescape(passphrase)?;
    ensure!(!decoded.is_empty(), "iwd Passphrase is empty");
    Ok(decoded)
}

fn _unescape(value: &str) -> Result<String> {
    let mut characters = value.chars();
    let mut decoded = String::new();
    while let Some(character) = characters.next() {
        if character != '\\' {
            decoded.push(character);
            continue;
        }
        decoded.push(match characters.next() {
            Some('s') => ' ',
            Some('t') => '\t',
            Some('r') => '\r',
            Some('n') => '\n',
            Some('\\') => '\\',
            _ => bail!("invalid escape in iwd Passphrase"),
        });
    }
    Ok(decoded)
}

#[expect(
    clippy::indexing_slicing,
    reason = "A nibble is always within the 16-digit table"
)]
fn _profile_name(ssid: &str) -> String {
    if ssid.bytes().all(|byte| {
        byte.is_ascii_alphanumeric() || b" _-".contains(&byte)
    }) {
        return ssid.to_owned();
    }
    std::iter::once('=')
        .chain(ssid.bytes().flat_map(|byte| {
            [byte >> 4, byte & 0xf]
                .map(|nibble| char::from(HEX[usize::from(nibble)]))
        }))
        .collect()
}

fn _payload(network: &Network, password: &str) -> String {
    let security = if network.security == "open" {
        "nopass"
    } else {
        "WPA"
    };
    format!(
        "WIFI:T:{security};S:{};P:{};H:{};;",
        _escape(&network.name),
        _escape(password),
        network.hidden
    )
}

fn _escape(value: &str) -> String {
    value
        .chars()
        .flat_map(|character| {
            let prefix = if "\\;,:\"".contains(character) {
                Some('\\')
            } else {
                None
            };
            prefix.into_iter().chain(std::iter::once(character))
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn personal_qr_escapes_credentials_and_marks_hidden_networks() {
        let network = Network {
            name: "a;,:\"\\".into(),
            security: "psk".into(),
            hidden: true,
        };
        assert_eq!(
            _payload(&network, "password;"),
            r#"WIFI:T:WPA;S:a\;\,\:\"\\;P:password\;;H:true;;"#
        );
    }

    #[test]
    fn profile_names_use_iwd_utf8_hex_encoding() {
        for (ssid, expected) in [
            ("Home _-1", "Home _-1"),
            ("../x", "=2e2e2f78"),
            ("café", "=636166c3a9"),
        ] {
            assert_eq!(_profile_name(ssid), expected);
        }
    }

    #[test]
    fn passphrases_follow_iwd_keyfile_escaping() -> Result<()> {
        assert_eq!(
            _passphrase(
                "[Security]\nPassphrase=\\sabc\\t\\r\\n\\\\\\s\n"
            )?,
            " abc\t\r\n\\ "
        );
        Ok(())
    }

    #[test]
    fn unreadable_or_unrecoverable_credentials_are_errors() {
        for content in [
            "[Settings]\nPassphrase=wrong",
            "[Security]\nPreSharedKey=012345",
            "[Security]\nEncryptedSecurity=secret",
            "[Security]\nPassphrase=",
            "[Security]\nPassphrase=bad\\x",
        ] {
            assert!(_passphrase(content).is_err());
        }
    }

    #[test]
    fn enterprise_credentials_are_never_shared_as_open() {
        let network = Network {
            name: "Work".into(),
            security: "8021x".into(),
            hidden: false,
        };
        assert!(
            _password(&network, Path::new("/nonexistent")).is_err()
        );
    }
}
