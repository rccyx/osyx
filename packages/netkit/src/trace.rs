use crate::unix::Arguments;
use anyhow::{Context, Result};
use std::{
    env, ffi::OsStr, os::unix::process::CommandExt, process::Command,
};

const ENTRYPOINT: &str = "netkit-trippy";

pub fn is_entrypoint() -> bool {
    env::args_os().next().as_deref() == Some(OsStr::new(ENTRYPOINT))
}

pub fn run(arguments: Arguments) -> Result<()> {
    // Trippy's library parses process argv internally. Re-enter this binary
    // without netkit's subcommand so the upstream TUI receives its own CLI.
    let failure = Command::new(env::current_exe()?)
        .arg0(ENTRYPOINT)
        .args(arguments.arguments)
        .exec();
    Err(failure).context("could not enter the linked Trippy TUI")
}

pub fn enter() -> Result<()> {
    trippy_tui::trippy()
}
