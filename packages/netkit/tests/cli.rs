use anyhow::{Context, Result};
use std::{
    fs,
    os::unix::fs::PermissionsExt,
    path::PathBuf,
    process::{Command, Output, Stdio},
    sync::atomic::{AtomicUsize, Ordering},
};

const NETKIT: &str = env!("CARGO_BIN_EXE_netkit");
static NEXT_DIRECTORY: AtomicUsize = AtomicUsize::new(0);

#[test]
fn tools_receive_arguments_without_shell_interpretation() -> Result<()>
{
    let fixture = Fixture::_new()?;
    let routes = [
        ("netspeed", "bandwhich", vec![]),
        ("speed", "cloudflare-speed-cli", vec![]),
        ("traffic", "bandwhich", vec![]),
        (
            "capture",
            "tcpdump",
            vec!["-i", "any", "-nn", "-tttt", "-l", "-q"],
        ),
        ("ping", "gping", vec![]),
        ("status", "ip", vec!["-brief", "address"]),
        ("routes", "ip", vec!["route"]),
        ("scan", "arp-scan", vec!["--localnet"]),
    ];
    for (command, tool, prefix) in routes {
        fixture._install(tool)?;
        let execution = fixture._invoke(&[
            command,
            "--",
            "--example",
            "a; $(literal)",
        ])?;
        assert!(
            execution.status.success(),
            "{command}: {execution:?}"
        );
        let database = fixture
            ._directory
            .join("share/netkit/arp-scan/ieee-oui.txt");
        let scan = if command == "scan" {
            vec![
                "--ouifile",
                database.to_str().context("non-UTF-8 test path")?,
            ]
        } else {
            vec![]
        };
        let expected =
            [prefix, scan, vec!["--example", "a; $(literal)"]]
                .concat();
        assert_eq!(_lines(&execution), expected, "{command}");
    }
    Ok(())
}

#[test]
fn wifi_executes_installed_impala_without_arguments() -> Result<()> {
    let fixture = Fixture::_new()?;
    fixture._install_body(("impala", "printf 'impala\\n'\n"))?;
    let execution = fixture._invoke(&["wifi"])?;
    assert!(execution.status.success(), "{execution:?}");
    assert_eq!(_lines(&execution), ["impala"]);
    Ok(())
}

#[test]
fn missing_impala_explains_how_to_install_it() -> Result<()> {
    let fixture = Fixture::_new()?;
    let execution = fixture._invoke(&["wifi"])?;
    assert_eq!(execution.status.code(), Some(1));
    let error = String::from_utf8_lossy(&execution.stderr);
    assert!(error.contains("impala is not installed"));
    assert!(error.contains("just setup"));
    Ok(())
}

#[test]
fn impala_failure_preserves_exit_code_and_stderr() -> Result<()> {
    let fixture = Fixture::_new()?;
    fixture._install_body((
        "impala",
        "printf 'iwd unavailable\\n' >&2\nexit 29\n",
    ))?;
    let execution = fixture._invoke(&["wifi"])?;
    assert_eq!(execution.status.code(), Some(29));
    assert_eq!(execution.stderr, b"iwd unavailable\n");
    Ok(())
}

#[test]
fn child_failure_preserves_exit_code_and_stderr() -> Result<()> {
    let fixture = Fixture::_new()?;
    fixture._install_body((
        "cloudflare-speed-cli",
        "printf 'upstream failure\\n' >&2\nexit 37\n",
    ))?;
    let execution = fixture._invoke(&["speed"])?;
    assert_eq!(execution.status.code(), Some(37));
    assert_eq!(execution.stderr, b"upstream failure\n");
    Ok(())
}

#[test]
fn missing_tool_names_the_dependency() -> Result<()> {
    let fixture = Fixture::_new()?;
    let execution = fixture._invoke(&["netspeed"])?;
    assert_eq!(execution.status.code(), Some(1));
    assert!(
        String::from_utf8_lossy(&execution.stderr)
            .contains("could not execute bundled bandwhich")
    );
    Ok(())
}

#[test]
fn trace_runs_linked_trippy_without_a_companion_executable()
-> Result<()> {
    let fixture = Fixture::_new()?;
    let execution = fixture._invoke(&["trace", "--", "--help"])?;
    assert!(execution.status.success(), "{execution:?}");
    assert!(
        String::from_utf8_lossy(&execution.stdout).contains("--tui")
    );
    Ok(())
}

#[test]
fn dns_rejects_invalid_record_types_before_network_access()
-> Result<()> {
    let fixture = Fixture::_new()?;
    let execution =
        fixture._invoke(&["dns", "example.com", "INVALID"])?;
    assert_eq!(execution.status.code(), Some(2));
    assert!(
        String::from_utf8_lossy(&execution.stderr)
            .contains("invalid value")
    );
    Ok(())
}

#[test]
fn every_command_exposes_help_without_dependencies() -> Result<()> {
    let fixture = Fixture::_new()?;
    for command in [
        "wifi", "qr", "status", "routes", "netspeed", "traffic",
        "speed", "ping", "trace", "dns", "scan", "watch", "capture",
    ] {
        let execution = fixture._invoke(&[command, "--help"])?;
        assert!(
            execution.status.success(),
            "{command}: {execution:?}"
        );
        assert!(
            String::from_utf8_lossy(&execution.stdout)
                .contains("Usage:")
        );
    }
    Ok(())
}

#[test]
fn watch_excludes_only_sockets_owned_entirely_by_named_processes()
-> Result<()> {
    let fixture = Fixture::_new()?;
    let rows = [
        "Netid State Local Peer Process",
        "tcp ESTAB local remote users:((\"chrome\",pid=1,fd=2))",
        "tcp ESTAB local remote users:((\"chrome\",pid=1,fd=2),(\"cargo\",pid=3,fd=4))",
        "tcp ESTAB local remote users:((\"chrome-helper\",pid=5,fd=6))",
        "udp UNCONN local remote",
    ];
    fixture._install_body((
        "ss",
        &format!("while IFS= read -r row; do printf '%s\\n' \"$row\"; done <<'SOCKETS'\n{}\nSOCKETS\n", rows.join("\n")),
    ))?;
    let execution = fixture._invoke(&[
        "watch",
        "--once",
        "--exclude",
        "chrome",
    ])?;
    assert!(execution.status.success(), "{execution:?}");
    let lines = _lines(&execution);
    assert!(!lines.iter().any(|line| line == rows[1]));
    for row in [rows[0], rows[2], rows[3], rows[4]] {
        assert!(
            lines.iter().any(|line| line == row),
            "missing {row}"
        );
    }
    Ok(())
}

#[test]
fn watch_rejects_incomplete_socket_snapshots() -> Result<()> {
    let fixture = Fixture::_new()?;
    fixture._install_body((
        "ss",
        "printf 'netlink denied\\n' >&2\nexit 0\n",
    ))?;
    let execution = fixture._invoke(&["watch", "--once"])?;
    assert_eq!(execution.status.code(), Some(1));
    assert!(
        String::from_utf8_lossy(&execution.stderr)
            .contains("netlink denied")
    );
    assert!(execution.stdout.is_empty());
    Ok(())
}

fn _lines(execution: &Output) -> Vec<String> {
    String::from_utf8_lossy(&execution.stdout)
        .lines()
        .map(String::from)
        .collect()
}

struct Fixture {
    _directory: PathBuf,
}

impl Fixture {
    fn _new() -> Result<Self> {
        let sequence = NEXT_DIRECTORY.fetch_add(1, Ordering::Relaxed);
        let directory = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join(format!(
                "target/cli-tests/{}-{sequence}",
                std::process::id()
            ));
        fs::create_dir_all(directory.join("bin"))?;
        fs::create_dir_all(directory.join("libexec/netkit/bin"))?;
        fs::hard_link(NETKIT, directory.join("bin/netkit"))?;
        Ok(Self {
            _directory: directory,
        })
    }

    fn _install(&self, tool: &str) -> Result<()> {
        self._install_body((
            tool,
            "for argument do printf '%s\\n' \"$argument\"; done\n",
        ))
    }

    fn _install_body(&self, script: (&str, &str)) -> Result<()> {
        let (tool, body) = script;
        let directory = if matches!(tool, "impala" | "ss" | "tcpdump")
        {
            "bin"
        } else {
            "libexec/netkit/bin"
        };
        let executable = self._directory.join(directory).join(tool);
        fs::write(&executable, format!("#!/bin/sh\n{body}"))?;
        fs::set_permissions(
            executable,
            fs::Permissions::from_mode(0o755),
        )?;
        Ok(())
    }

    fn _invoke(&self, arguments: &[&str]) -> Result<Output> {
        Ok(self._command(arguments).output()?)
    }

    fn _command(&self, arguments: &[&str]) -> Command {
        let mut command =
            Command::new(self._directory.join("bin/netkit"));
        command
            .args(arguments)
            .env("PATH", self._directory.join("bin"))
            .stdin(Stdio::null())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped());
        command
    }
}

impl Drop for Fixture {
    fn drop(&mut self) {
        assert!(fs::remove_dir_all(&self._directory).is_ok());
    }
}
