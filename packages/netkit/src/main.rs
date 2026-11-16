mod cli;
mod dns;
mod trace;
mod unix;
mod wifi;

use clap::Parser;
use cli::{Cli, Commands};
use std::process::ExitCode;

fn main() -> ExitCode {
    let execution = if trace::is_entrypoint() {
        trace::enter()
    } else {
        _run(Cli::parse().command)
    };
    match execution {
        Ok(()) => ExitCode::SUCCESS,
        Err(failure) => {
            eprintln!("netkit: {failure:#}");
            ExitCode::FAILURE
        }
    }
}

fn _run(command: Commands) -> anyhow::Result<()> {
    match command {
        Commands::Wifi(options) => wifi::run(options),
        Commands::Qr(options) => wifi::share(options),
        Commands::Status(arguments) => unix::bundled(
            "ip",
            arguments.prefixed(&["-brief", "address"]),
        ),
        Commands::Routes(arguments) => {
            unix::bundled("ip", arguments.prefixed(&["route"]))
        }
        Commands::Netspeed(arguments)
        | Commands::Traffic(arguments) => {
            unix::bundled("bandwhich", arguments.arguments)
        }
        Commands::Speed(arguments) => {
            unix::bundled("cloudflare-speed-cli", arguments.arguments)
        }
        Commands::Ping(arguments) => {
            unix::bundled("gping", arguments.arguments)
        }
        Commands::Trace(arguments) => trace::run(arguments),
        Commands::Dns(query) => dns::lookup(query),
        Commands::Scan(arguments) => unix::scan(arguments),
    }
}
