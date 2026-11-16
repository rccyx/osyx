# netkit

A unified Linux networking CLI built in Rust. Wi-Fi management, QR sharing, DNS, diagnostics, traffic inspection, and network discovery from one command.

## Installation

```bash
just install
```

Installs `netkit` and its bundled utilities to `~/.local` by default.

```bash
just setup           # Install required dependencies
just f               # Format Rust sources
just fc              # Check formatting
just l               # Run strict Clippy checks on all targets and features
just t               # Run unit and integration tests
just b               # Build the release binary
just check           # Run formatting, Clippy, and tests
just bundle          # Build bundled utilities
just verify-bundle   # Verify the bundle
just uninstall       # Remove netkit
```

Requires Linux, Rust 1.95+, and the relevant system dependencies. The installation scripts target Debian-based distributions.

## Commands

| Command | Description |
|---|---|
| `netkit wifi` | Launch the Impala Wi-Fi TUI |
| `netkit wifi on` | Enable iwd Wi-Fi adapters |
| `netkit wifi off` | Disable iwd Wi-Fi adapters |
| `netkit qr` | Display the connected Wi-Fi credentials and QR code |
| `netkit status` | Show interfaces and IP addresses |
| `netkit routes` | Show the routing table |
| `netkit netspeed` | Monitor network bandwidth |
| `netkit traffic` | Inspect traffic by process and connection |
| `netkit speed` | Test internet speed and latency |
| `netkit ping <host>` | Graph network latency |
| `netkit trace <host>` | Interactive traceroute |
| `netkit dns <host> [type]` | Query DNS records |
| `netkit scan` | Discover devices on the local network |

### Examples

```bash
netkit wifi
netkit qr
netkit qr -i wlan0

netkit status
netkit routes
netkit netspeed
netkit traffic

netkit speed
netkit ping google.com
netkit trace google.com
netkit dns google.com AAAA
netkit scan
```

Pass additional options directly to the underlying tools:

```bash
netkit traffic -- --interface wlan0 --raw
netkit speed -- --text --auto-save false
netkit trace google.com --unprivileged
netkit scan -- --interface=wlan0
```
