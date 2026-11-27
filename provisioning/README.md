# Provisioning

OSYX workstation setup for Debian 13 (Trixie).

## Bootstrap

Create a normal Linux user and clone OSYX into a directory that user can read.
From the repository root, run as root:

```sh
./provisioning/bootstrap --user YOUR_USER
```

Use `--yes` to install the entire workstation without prompts:

```sh
./provisioning/bootstrap --user YOUR_USER --yes
```

Bootstrap installs sudo, Git, Python, curl and CA certificates first. It then
copies the tracked contents of `home/`, including `flavors/`, installs the
missing APT packages and provisions the remaining workstation resources.

The workstation includes networking, audio, desktop utilities, terminal
tools, appearance, development tools, login support, runtimes and every
enabler.

Existing conflicting home files are preserved. Use `--replace-home` to
replace them and retain their original contents for destruction.

Intel firmware requires `--firmware-intel` in unattended mode. Open an issue for other hardware. 

## Usage

Run from the repository root as your workstation user:

```sh
./provisioning/main plan workstation
./provisioning/main apply workstation --yes
./provisioning/main doctor workstation
```

| Command | Behavior |
| --- | --- |
| `plan TARGET` | Preview the changes |
| `apply TARGET` | Install or configure the target |
| `doctor TARGET` | Verify the installed target |
| `destroy TARGET` | Remove changes owned by provisioning |
| `plan TARGET --destroy` | Preview removal |

Targets can be individual packages or groups:

```sh
./provisioning/main apply btop
./provisioning/main destroy btop

./provisioning/main apply runtimes
./provisioning/main apply fonts
./provisioning/main destroy fonts

./provisioning/main apply battery
./provisioning/main destroy battery
```

The `runtimes` group installs Go, Node, pnpm, uv, CPython and Rust.
The `enablers` group contains battery and heat notifications, screenshots,
screen sharing and Vocaster control.

Root invocation requires `--user YOUR_USER` unless `SUDO_USER` identifies
the account. Noninteractive apply and destroy require `--yes`.

## Dependencies

Add packages to the appropriate file under `deps/`. Every package declaration
needs a comment explaining its purpose so this doesn't get stuck in slop limbo.

```text
# deps/apt/terminal.deps
btop # resource monitor

# deps/cargo.deps
starship==1.27.0 # shell prompt
```

APT packages use Debian's available versions by default. Cargo, pipx and
pnpm tools are pinned. pipx constraints and pnpm lockfiles are in
`deps/locks/`. Update the associated lockfile whenever a pinned tool
changes.

Runtime and binary releases are declared in `deps/releases.toml`.
Font, GTK and shell sources are declared in `deps/appearance.toml`.
Enabler dependencies and installed paths are declared in
`enablers/manifest.toml`.

The provisioner's Python code reads these declarations and resolves
dependencies automatically. Ordinary packages do not need custom installers.

## Ownership

System receipts in `/var/lib/osyx/provisioning/`.
User receipts in `~/.local/state/osyx/provisioning/`.
Managed binary packages in `~/.local/share/osyx/packages/` with
commands exposed through `~/.local/bin/`.

The receipt records what was installed and the previous contents of replaced
files. Destroy uses these records to remove managed changes and restore
original files. Existing unowned packages are retained. Modified managed
files can cause a conflict rather than being overwritten.

OSYX fonts are under `~/.local/share/fonts/osyx/`. 

Do not delete receipts while resources are installed. The five stage-zero

