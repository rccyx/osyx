use crate::{
    dns::Lookup,
    unix::Arguments,
    wifi::{WifiInterface, WifiOptions},
};
use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(
    version,
    about = "Network tools through one Unix interface"
)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Manage Wi-Fi and launch the wireless TUI
    Wifi(WifiOptions),
    /// Show the connected Wi-Fi password and a scannable join QR code
    Qr(WifiInterface),
    /// Show interfaces and addresses (ip)
    Status(Arguments),
    /// Show routing table (ip route)
    Routes(Arguments),
    /// Show live bandwidth by process and connection (bandwhich)
    Netspeed(Arguments),
    /// Inspect live traffic by process, connection, and remote address (bandwhich)
    Traffic(Arguments),
    /// Measure internet upload, download, and latency (Cloudflare)
    Speed(Arguments),
    /// Graph latency to hosts (gping)
    Ping(Arguments),
    /// Inspect network paths interactively (trippy)
    Trace(Arguments),
    /// Query DNS records through the system-configured resolver (Hickory)
    Dns(Lookup),
    /// Discover devices on the local network (arp-scan)
    Scan(Arguments),
}
