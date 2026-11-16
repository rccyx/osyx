use crate::unix::{self, Arguments};
use anyhow::{Context, Result, ensure};
use clap::Args;
use std::{
    io::{self, IsTerminal, Write},
    process::Command,
    thread,
    time::Duration,
};

#[derive(Args)]
pub struct WatchOptions {
    /// Hide rows owned exclusively by these exact process names; repeatable
    #[arg(long = "exclude", value_name = "PROCESS")]
    _exclude: Vec<String>,
    /// Print a single socket snapshot and exit
    #[arg(long = "once")]
    _once: bool,
}

pub fn watch(options: &WatchOptions) -> Result<()> {
    let terminal = io::stdout().is_terminal();
    let mut output = io::stdout().lock();
    loop {
        let snapshot = _snapshot()?;
        if terminal && !options._once {
            write!(output, "\x1b[2J\x1b[H")?;
        }
        writeln!(
            output,
            "TCP/UDP sockets and listeners | refresh 1s | Ctrl-C to stop"
        )?;
        writeln!(
            output,
            "Process ownership may require root. Unattributed sockets remain visible."
        )?;
        for row in snapshot
            .lines()
            .filter(|row| !_excluded(row, &options._exclude))
        {
            writeln!(output, "{row}")?;
        }
        output.flush()?;
        if options._once {
            return Ok(());
        }
        thread::sleep(Duration::from_secs(1));
    }
}

pub fn capture(arguments: Arguments) -> Result<()> {
    unix::installed(
        "tcpdump",
        arguments
            .prefixed(&["-i", "any", "-nn", "-tttt", "-l", "-q"]),
    )
}

fn _snapshot() -> Result<String> {
    let execution = Command::new("ss")
        .args([
            "--tcp",
            "--udp",
            "--all",
            "--numeric",
            "--processes",
            "--oneline",
        ])
        .output()
        .context("could not execute ss; run just setup")?;
    // ss can report netlink permission failures while exiting successfully.
    ensure!(
        execution.status.success() && execution.stderr.is_empty(),
        "ss could not inspect sockets: {}",
        String::from_utf8_lossy(&execution.stderr).trim()
    );
    String::from_utf8(execution.stdout)
        .context("ss returned non-UTF-8 socket information")
}

fn _excluded(row: &str, excluded: &[String]) -> bool {
    let Some((_, owners)) = row.split_once("users:(") else {
        return false;
    };
    let mut names = owners.split("(\"").skip(1).peekable();
    names.peek().is_some()
        && names.all(|owner| {
            owner.split_once('\"').is_some_and(|(name, _)| {
                excluded.iter().any(|excluded| excluded == name)
            })
        })
}
