# syncer

Snapshot the machine's packages into `sync.lock.json`, keep the snapshot in Git,
and replay it on another machine. Linux, Python 3.12+, uv, and Just.

## Working

From the repo root:

```sh
cd packages/syncer
just install
syncer --help
```

`just install` installs a standalone copy with `uv tool install`, exposing
`syncer` in `~/.local/bin`. Make sure it's in `PATH.

Rerun `just install` after changing the source to update the installed copy.

To uninstall from anywhere:

```sh
uv tool uninstall syncer
```

From this package directory, `just uninstall` does the same thing. It leaves your
snapshots alone.

## Commands

```sh
syncer backup
syncer status
syncer diff
syncer restore --dry-run
syncer restore
```

Snapshots go into `~/packages` by default. Change that with `PACKAGES_DIR`, or put
`--pkg-dir` **before** the command:

```sh
syncer --pkg-dir "$HOME/machine-packages" backup
syncer --pkg-dir "$HOME/machine-packages" restore --dry-run
```

## How it works

1. Reads the installed package managers and records their current state.
2. Saves APT sources/keyrings, dpkg selections, and GNOME media-key bindings when
   the corresponding tools are available.
3. Writes `sync.lock.json` atomically, with the timestamp, hostname, OS, and package
   inventory.
4. If the snapshot directory contains a `.git` directory, stages **everything** in
   it, commits changes, and pushes to its configured remote.

[!NOTE]
> Use a dedicated snapshot repository with a working remote and Git identity if you want automatic pushes. Without `.git`, backup only writes the local files.

[!NOTE]
> Package managers must already be installed and discoverable on `PATH`.

| Inventory | Captured | Replayed by `restore` |
| --- | --- | --- |
| APT | Manually installed packages minus installer defaults, versions, architectures | Versioned installs, falls back to the available version |
| mise | Global tool versions | `mise use --global`, then `mise install` |
| Cargo | Installed crates and versions | Versioned installs |
| npm / pnpm | Global packages and versions | Versioned global installs |
| pipx | Applications, versions, Python version, injected packages | Applications and injections, existing pipx chooses Python |
| uv tools | Tool names | Installs by name, without a version pin |
| Go | Binary module paths and versions | Versioned module installs |
| rustup | Toolchain names | Installs those toolchains |
| Nix | Profile references | Installs references, with a `nixpkgs#` fallback |
| System pip3 | Freeze output from a non-Conda pip3 | Inventory only |
| Snap / Flatpak | Installed application names | Inventory only |

## What restore does

First runs `git pull --ff-only` when the snapshot directory is a Git repo,
then reads its lockfile. It restores APT configuration and GNOME bindings before
replaying packages. It requests sudo credentials for a real restore. A nonempty
inventory requires its package manager to be installed and on `PATH`.

```sh
syncer restore --dry-run
syncer restore --no-apt-update
syncer restore --strict
```

## Errors

Failed commands raise exceptions. The CLI prints the command, exit code, and stderr,
then exits with status 1. Git, sudo, package installs, injections, and configuration
copies all use checked execution. A failed capture stops backup before replacing
the lockfile. Malformed snapshots and unsupported schemas are rejected.

APT, pipx, and Nix report a failed pinned install before attempting their fallback.
If that fails too, restore stops. Missing managers are omitted during backup;
restoring packages for a missing manager is an error.
