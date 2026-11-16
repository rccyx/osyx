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
| `netkit watch` | Watch TCP/UDP sockets, listeners, PIDs, and process names |
| `netkit capture` | Stream packet headers, including incoming pings |
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

For continuous inspection, use separate terminals:

```bash
sudo ~/.local/bin/netkit traffic
sudo ~/.local/bin/netkit watch --exclude chrome
sudo ~/.local/bin/netkit capture
```

`watch` refreshes every second.

Repeat `--exclude` for exact process names sockets with unknown owners or another owner remain visible. 

Use `--once` for a single snapshot. 

`capture` uses the installed `tcpdump` on all interfaces, showing numeric
addresses and packet summaries without printing payloads by default.

It observes incoming and outgoing packets, including traffic without an
owning socket. Pass tcpdump options or capture filters after `--`:

```bash
sudo ~/.local/bin/netkit capture -- -Q in
sudo ~/.local/bin/netkit capture -- 'icmp or icmp6'
```
