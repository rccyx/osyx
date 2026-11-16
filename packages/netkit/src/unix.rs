use anyhow::{Context, Result};
use clap::Args;
use std::{
    env,
    ffi::{OsStr, OsString},
    os::unix::process::CommandExt,
    path::PathBuf,
    process::Command,
};

#[derive(Args)]
pub struct Arguments {
    /// Arguments passed directly to the underlying utility; use -- before flags
    #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
    pub arguments: Vec<OsString>,
}

impl Arguments {
    pub fn prefixed(self, prefix: &[&str]) -> Vec<OsString> {
        prefix
            .iter()
            .map(OsString::from)
            .chain(self.arguments)
            .collect()
    }
}

pub fn bundled(
    program: &str,
    arguments: impl IntoIterator<Item = impl AsRef<OsStr>>,
) -> Result<()> {
    let tool = _root()?.join("libexec/netkit/bin").join(program);
    let failure = Command::new(&tool).args(arguments).exec();
    Err(failure).with_context(|| {
        format!(
            "could not execute bundled {program} at {}; run tooling/bundle",
            tool.display()
        )
    })
}

pub fn installed(
    program: &str,
    arguments: impl IntoIterator<Item = impl AsRef<OsStr>>,
) -> Result<()> {
    let failure = Command::new(program).args(arguments).exec();
    if failure.kind() == std::io::ErrorKind::NotFound {
        anyhow::bail!(
            "{program} is not installed; run just setup in the netkit directory"
        );
    }
    Err(failure)
        .with_context(|| format!("could not execute {program}"))
}

pub fn scan(arguments: Arguments) -> Result<()> {
    let database =
        _root()?.join("share/netkit/arp-scan/ieee-oui.txt");
    let prefix = [
        OsString::from("--localnet"),
        OsString::from("--ouifile"),
        database.into_os_string(),
    ];
    bundled("arp-scan", prefix.into_iter().chain(arguments.arguments))
}

fn _root() -> Result<PathBuf> {
    let executable = env::current_exe()
        .context("could not locate netkit executable")?;
    executable
        .parent()
        .and_then(|directory| directory.parent())
        .map(PathBuf::from)
        .context("netkit executable has no installation root")
}
