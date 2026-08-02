<div align="center">

# hyprtryx

Builds a pinned, curated Hyprland session stack from source on Debian Trixie.

## Output

If everything is installed, and you run it again, you get everything  cached (idempotent by default):

```bash
bash ./main apply --yes
hyprtryx v0.4.1
snapshot: 2026-08-01
prefix:   /usr/local
state:    /home/rccyx/.local/state/hyprtryx/state.env
cache:    /home/rccyx/.cache/hyprtryx
log:      /home/rccyx/.cache/hyprtryx/logs/20260802-123101-apply.log

[ok] apt deps already satisfied; skip apt update
[ok] compiler: CC=/usr/bin/clang-19
[ok] compiler: CXX=/usr/bin/clang++-19
[warn] standard library lacks std::ranges::starts_with; compatibility patch enabled
[ok] dep cache: xkbcommon 1.13.1
[ok] dep cache: wayland-scanner 1.25.0
[ok] dep cache: wayland-protocols 1.49
[ok] dep cache: libinput 1.29.0
[ok] dep cache: lua5.5 5.5.0
[ok] component cache: hyprutils (0.14.0)
[ok] component cache: hyprwayland-scanner (0.4.6)
[ok] component cache: hyprland-protocols (0.7.0)
[ok] component cache: hyprlang (0.6.8)
[ok] component cache: hyprgraphics (0.5.1)
[ok] component cache: hyprwire (0.3.1)
[ok] component cache: aquamarine (0.14.0)
[ok] component cache: hyprcursor (0.1.13)
[ok] component cache: hyprtoolkit (0.5.4)
[ok] component cache: Hyprland (0.56.0+46)
[ok] component cache: hypridle (0.1.8)
[ok] component cache: hyprlock (0.9.6)
[ok] component cache: xdg-desktop-portal-hyprland (1.4.1)
[ok] component cache: hyprpaper (0.8.4+1)
[ok] component cache: hyprsunset (0.4.0)
[ok] component cache: hyprshutdown (0.1.1)
Place your right index finger on the fingerprint reader
[ok] seatd access: video
[info] validate installed stack
[ok] component probes, ABI resolution, and SDDM session entry passed
[ok] done

Hyprland: /usr/local/bin/Hyprland
Hyprland 0.56.0 built from branch  at commit ab95888cd1d6961471f9e8df05f5e4a40dbb759d dirty (config/values: adjust requirements for values ( 15654)).
Date: Thu Jul 30 12:00:23 2026
Tag: , commits: 1

Libraries:
Hyprgraphics: built against 0.5.1, system has 0.5.1
Hyprutils: built against 0.14.0, system has 0.14.0
Hyprcursor: built against 0.1.13, system has 0.1.13
Hyprlang: built against 0.6.8, system has 0.6.8
Aquamarine: built against 0.14.0, system has 0.14.0

Version ABI string: ab95888cd1d6961471f9e8df05f5e4a40dbb759d_aq_0.14_hu_0.14_hg_0.5_hc_0.1_hlg_0.6
no flags were set
```


## Stack

It builds the compositor, the session components used by this desktop, and only the libraries required by those components:

```text
Hyprland
├── hyprutils
├── hyprwayland-scanner
├── hyprland-protocols
├── hyprlang
├── hyprgraphics
├── aquamarine
└── hyprcursor

session
├── hypridle
├── hyprlock
├── hyprsunset
├── hyprshutdown
├── xdg-desktop-portal-hyprland
└── hyprpaper
    ├── hyprwire
    └── hyprtoolkit
```

The snapshot is pinned to exact commits captured on **2026-08-01**.

## Usage

Just like Terraform:

```bash
chmod +x ./main
./main plan
./main apply --yes
./main doctor
```


`doctor` validates the entire curated stack. It checks component ownership, managed shared library SONAMEs, runtime resolution, unresolved dependencies, the Hyprland executable, and the SDDM session entry. The session must launch `start-hyprland`.

Don't log out or reboot after a failed migration until `./main doctor` passes.

## Cache & State 

```text
~/.cache/hyprtryx/
├── build/
├── downloads/
├── logs/
│   └── components/
├── src/
└── stage/

~/.local/state/hyprtryx/
├── manifests/
└── state.env
```

The component identity includes the exact source ref, configure flags, prefix, dependency chain, compatibility patch revision, and runtime link revision. Scheduling changes do not invalidate object files.

The automatic job count is constrained by CPU count and available host or cgroup memory. Override it without invalidating caches:

```bash
HYPRTRYX_JOBS=2 ./main apply --yes
```


## Removal

Uninstall managed files while preserving active source and build caches:

```bash
./main remove
```

Reinstalling after `remove` restores completed stages before compiling.

Wipe every managed installation and cache:

```bash
./main reset --yes
```

## ABI safety

Every CMake configure refreshes cached `pkg-config` lookups and then pins discovered managed libraries to the exact shared objects selected by their `.pc` files. This prevents source built headers from being paired with older Debian libraries.

Before replacing a managed Hypr or Aquamarine shared library family, hyprtryx removes stale versions of that family. Validation then checks:

- owned Hypr and Aquamarine libraries publish valid SONAMEs
- SONAME symlinks and `ldconfig` resolution are correct
- managed executables contain no unversioned Hypr dependency
- source built Hypr, Aquamarine, libinput, and xkbcommon dependencies resolve from `/usr/local/lib`
- `ldd` reports no missing library

System dependencies such as libinput are validated through runtime resolution rather than being forced to follow Hypr's SONAME policy. This avoids rejecting a valid Meson library solely because its real file does not carry the layout expected from Hypr libraries.

The build environment does not export `LD_LIBRARY_PATH`, so validation observes the same loader behavior as a normal login session.

## Source built minimums

Trixie packages are used when sufficient. Otherwise hyprtryx builds and caches:

- libxkbcommon 1.11.0
- wayland-scanner 1.25.0
- wayland-protocols 1.49
- libinput 1.29.0
- Lua 5.5.0, verified by SHA-256

Lua includes the C headers and `lua.hpp` required by Hyprland. Narrow compatibility patches are enabled only when the selected Trixie standard library lacks an API used by the pinned source.

## Debian isolation

When every package is already installed, `apply` skips APT entirely. Otherwise the transaction uses an isolated Debian Trixie source definition, so enabled Sid or third party repositories are not consulted.

Packages installed by an older hyprtryx version are not automatically removed. hyprtryx owns its installed files, not Debian packages that may also be used by unrelated software. Fresh v0.4 installations request only the curated stack's package set.

## License

Apache-2.0 © [@rccyx](https://rccyx.com).
