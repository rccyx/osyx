<div align="center">

# **_osyx_**

<p align="center"><i>Bespoke OS, built from bare Debian upward.</i></p>

<p align="center">
  <a href="https://github.com/rccyx/osyx/actions">
    <img src="https://img.shields.io/github/actions/workflow/status/rccyx/osyx/ci.yml?style=for-the-badge&color=black&labelColor=111111&logo=githubactions&logoColor=white" alt="CI Status"/>
  </a>
  <a href="https://www.debian.org/releases/trixie/">
    <img src="https://img.shields.io/badge/Base-Debian_Trixie-black?style=for-the-badge&color=black&labelColor=111111&logo=debian&logoColor=white" alt="Base: Debian Trixie"/>
  </a>
  <a href="#can-i-use-this-today">
    <img src="https://img.shields.io/badge/Beta-black?style=for-the-badge&color=black&labelColor=111111" alt="Status: Work In Progress"/>
  </a>
  <a href="https://github.com/rccyx/osyx">
    <img src="https://img.shields.io/github/repo-size/rccyx/osyx?style=for-the-badge&color=black&labelColor=111111&logo=github&logoColor=white" alt="Size"/>
  </a>
  <a href="https://github.com/rccyx/osyx/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/License-Apache-black?style=for-the-badge&color=black&labelColor=111111&logo=apache&logoColor=white" alt="License: Apache"/>
  </a>
</p>

</div>

<table>
  <tr>
    <td><img width="100%" alt="osyx desktop" src="https://github.com/user-attachments/assets/fbd42023-8349-4f86-8bca-e136d4684a56" /></td>
    <td><img width="100%" alt="osyx desktop" src="https://github.com/user-attachments/assets/56449dd3-0939-4a28-93df-03fe38159e04" /></td>
  </tr>
  <tr>
    <td><img width="100%" alt="osyx desktop" src="https://github.com/user-attachments/assets/bc9208f7-a41e-4657-8449-ad73ab258a01" /></td>
    <td><img width="100%" alt="osyx desktop" src="https://github.com/user-attachments/assets/c654542a-59b1-46ee-9571-9e412d2b0202" /></td>
  </tr>
  <tr>
    <td><img width="100%" alt="osyx desktop" src="https://github.com/user-attachments/assets/80141186-0a5a-4cef-ad3b-c9222a1b4f20" /></td>
    <td><img width="100%" alt="osyx desktop" src="https://github.com/user-attachments/assets/4ad3033e-8651-4c8c-988e-0fafd016d932" /></td>
  </tr>
  <tr>
    <td><img width="100%" alt="osyx desktop" src="https://github.com/user-attachments/assets/8475976a-f782-4dbe-8fb6-5509e8deb4cc" /></td>
    <td><img width="100%" alt="osyx desktop" src="https://github.com/user-attachments/assets/94624f38-8e32-45d8-9723-924b7a56f0f1" /></td>
  </tr>
</table>


## Demo

<div align="center">
  <video src="https://github.com/user-attachments/assets/2dfe5dcd-08f7-4e5f-8802-9f6263ede7f9" width="100%" controls>
    Your browser does not support the video tag.
  </video>
</div>

> [!IMPORTANT]
> This is still in beta, there's no one command install yet, but you can already pull individual pieces (the theming setup, the login screen, the standalone tools) and run them today. See [Can I use this today?](#can-i-use-this-today)

## Explainer

This is a bespoke OS layer that attaches to a clean base OS. 

Not dots, nor a distro. 

Starting with bare Debian (Trixie) for now, and extending to others in the future (Arch, etc). 

Which converts a blank TTY into a hyper optimized and premium looking workstation in minutes.

Everything is built/assembled from scratch (base slate doesn't even include `sudo`), and to make it all cohesive: the login screen, the power menu, the theming, everything, even the Hyprland builder (compiles all hypr programs for Debian) work together in unison.  

If a program doesn't fit, I just make a custom made one that fits.

It gives a pristine, premium feel of macOS built on 100% open-source software.

It's been my daily driver for years at this point. Excellent for engineering, it doesn't brick on Monday mornings, it just works and looks good. 

Haven't touched macOS/Windows in years.

Figured I might as well start open-sourcing this whole setup, so I'm dropping projects one by one.

## Product

I want my experience to operate like a HUD, but also look elegant.

I have an issue with bloated menus, icons everywhere, flashy drop downs, too many built in apps, choice fatigue, ugly fonts, etc.

So, everything in here only surfaces when you actually need to see it. Even the top bar is gone.

The system builds itself layer by layer. 

When it builds, it's lightweight, bloat-free, and completely reproducible and extendable.

### Zero cognitive pollution

**On-demand metrics:** Vitals surface only when you need them: Notifications show alerts only when the battery hits 50%, 33%, 25%, 15%, 10%, and 5%. If thermals spike or network drops, the system auto-notifies you.

Need time or system status? Hit `Alt + M` to invoke the control center or check Starship in your terminal. Otherwise, the desktop is completely empty.

Not even a workspace indicator exists here: `Super + 1` is always workspace one (Obsidian). `Super + 2` is always 2 and so on (browser). `Super + 3` is always terminal. 

Spatial memory makes workspace indicators redundant.

### Keybinds

Keyboard shortcut is the way, no dropdowns/menus/icons.

| Keys | Action |
| :--- | :--- |
| `Alt + W` | Speech to text |
| `Alt + P` | Power menu (lock, reboot, shutdown, suspend) |
| `Alt + M` | Control center (Bluetooth, Wifi, check weather, see connected devices, temp/RAM/heat metrics, battery, date, togglers for sounds & night mode) |
| `Alt + L` | Lock screen |
| `Alt + R` | Auto rotate system themes |
| `Alt + G` | Browser |
| `Alt + K` | Terminal |
| `Super + Alt + 1/2/3..` | Move window to workspace |
| `Super + Alt + Arrows` | Move window inside workspace |
| `Ctrl + 1/2/3..` | Change workspaces |
| `Ctrl + X` | Clipboard |
| `Super + F` | Full screen |
| `Super + Q` | Close window |

Set up a key and so on, till the keys run out.

But the prime real estate ran out a long time ago, so the CLI handles the rest.

### CLI

Most tasks are handled through `fzf` autocompletion, as there's only so much one can remember.

This includes everything from encryption, 2FA codes, network management, cloud analysis, reminders, syncing packages across Rust, TypeScript, Go, Python, APT, and whatever else, to Git ops, pull request management, reviews, submits, even ISO flashing, video editing, audio routing, and much more.

It covers basically anything that doesn't really require a full blown GUI to use.

Which if you think about it, most things.

### Apps

Apps behave like native apps. For example, `app sc` launches SoundCloud, `app yt` for YouTube, with Hyprland: `Super + F` for fullscreen, and `Super + Q` to quit. It's significantly faster than fumbling with browser tabs and saves seconds of friction every time.

## Custom Tooling

These are my custom programs (same design system, philosophy, everything):

| Package | Written | Description |
| :--- | :--- | :--- |
| **[`asryx`](https://github.com/rccyx/asryx)** | C++ | Offline, daemonless voice-to-text CLI (GGML Whisper + Silero VAD). Zero idle RAM. |
| **[`lookas`](https://github.com/rccyx/lookas)** | Rust | Auditory-perceptual audio visualizer using Mel scaling & spring damper physics. |
| **[`thyx`](https://github.com/rccyx/thyx)** | QML | Atomic SDDM login screen with video backgrounds and PAM fingerprint auth. |
| **[`powyx`](/packages/powyx)** | QML / Shell | Zero-overhead power menu HUD (`lock`, `suspend`, `reboot`, `shutdown`). |
| **`ctrlyx`** | C++ / QML | Daemonless control center HUD for hardware stats, weather, network management, and more. |
| **`clipyx`** | C++ / QML | SQLite-backed clipboard manager HUD with background capture, category tabs, search, and text/image previews. |
| **[`flavors`](/packages/flavors)** | Python | Dynamic color engine that generates matching themes across the desktop/login. |
| **[`totpyx`](/packages/totpyx)** | Rust | Zero dependency RFC 6238 TOTP generator and strict RFC 4648 Base32 decoder CLI/library. |
| **[`netkit`](/packages/netkit)** | Rust | Unified Linux networking CLI for `iwd` Wi-Fi, QR sharing, traffic/socket inspection, packet capture, DNS, and scanning. |
| **[`syncer`](/packages/syncer)** | Python | Atomic package and config snapshotter (`sync.lock.json`) with Git sync and multi-manager restore. |
| **[`hypr-builder`](/builders/hypr-builder)** | Shell | Bare-metal source builder compiling pinned Hyprland (`v0.56+`) and 15 ecosystem components with isolated fallback dependencies on Debian Trixie. |
| **[`gcc-builder`](/builders/gcc-builder)** | Shell | Bare-metal source builder compiling pinned GNU GCC `16.1.0` (`C`/`C++`) with C++26 verification on Debian Trixie. |

And other smaller utilities under `./packages`.

### Core utilities

| Layer | Pin |
| :--- | :--- |
| Distro | Debian `v13` |
| Display | Wayland `v1.24.0` |
| Compositor | Hyprland `v0.56.0`, built from `main` |
| Lockscreen | Hyprlock `v0.9.5` |
| Terminal | Kitty `v0.41.1` |
| Multiplexer | Tmux `v3.5a` |
| Shell | Zsh `v5.9` + Starship `v1.23.0` + Lsd `v1.1.5` |
| Notifications | Mako `v1.10.0-1` |
| [Fonts](https://github.com/rccyx/osyx/releases/tag/fonts-v1.0.0) | Inter (sans), Iosevka (mono), Meslo (Nerd Font fallback), Jakarta Sans (login) |
| Audio | PipeWire `v1.4.2` |

## Bootstrap

This is WIP. But have a look at `./provisioning/` and this [CI workflow](./.github/workflows/on-workflow-call-bootstrap.yml) 

### Hypr Builders

The current Hyprland version is v0.56.0, compiled Jul 30th 2026.

You might be asking, how am I on Debian and still got the latest hyprland?

Debian Trixie ships older system libraries and compiler toolchains than upstream Hyprland requires.

Well, just pin & compile them from scratch.

We setup a C++26 compiler, then use it to compile the entire Hypr stack (or only the ones needed).

- **[`gcc-builder`](/builders/gcc-builder):** Downloads and SHA-512-verifies GNU GCC `16.1.0` (`C` and `C++`), installs it, links `/usr/local/bin/gcc` and `/usr/local/bin/g++`, and runs a `-std=gnu++26` compile/execute probe to verify C++26 support.

- **[`hypr-builder`](/builders/hypr-builder):** Compiles 16 pinned Hyprland ecosystem commits (`hyprutils`, `hyprwayland-scanner`, `hyprland-protocols`, `hyprlang`, `hyprgraphics`, `hyprwire`, `aquamarine`, `hyprcursor`, `hyprtoolkit`, `Hyprland`, `hypridle`, `hyprlock`, `xdg-desktop-portal-hyprland`, `hyprpaper`, `hyprsunset`, and `hyprshutdown`) into `/usr/local`. 

Both builders work like Terraform (`./main plan | apply --yes | doctor | reset --yes`).

### Future Vision

When this is done, basically all you need is a USB stick with a bare metal distro and `curl`.

You Jason Bourne with one command, and minutes later a completely empty machine morphs into this exact hyper optimized workstation.

Totally disposable and reproducible. **No ISO needed.**

## Can I use this today?

Yes. 

There's no one command install yet, so the way to go by this right now is component extraction. 

Just grab what you want & wire it into your own setup.

```
osyx/
├── builders/       # Bare-metal source builders (gcc-builder, hypr-builder)
├── config/         # System dotfiles (~/.config mirrors, zsh functions)
├── packages/       # Standalone tools (asryx, ctrlyx, flavors, lookas, netkit, powyx, syncer, thyx, totpyx)
├── provisioning/   # Bootstrap, runtime setups, and app provisioners
└── docs/           # Docs
```

Read the [docs](/docs/starting.md).

## Custom Tools

Standalone tools I wrote from scratch. 

Most can be airdropped into any distro with one command (Λ). Some are specific to this setup (Δ).

### [lookas](https://github.com/rccyx/lookas) (Λ)

A terminal audio visualizer built around human auditory perception. It moves beyond raw FFT twitchiness using Mel scaling and spring damper physics.

```sh
cargo install lookas && lookas
```

<p align="center">
  <a href="https://github.com/rccyx/lookas">
    <img src="./assets/lookas.gif" alt="lookas demo" width="100%">
  </a>
</p>

### [asryx](https://github.com/rccyx/asryx) (Λ)

Pure C++ voice to text binary for Linux, done the UNIX way. No dependencies beyond the standard C++ and Linux toolchain.

It links to GGML Whisper (100% offline), records through the active Linux audio stack, transcribes locally, copies the output, notifies the session, and exits.

Tap once, speak for as long as you want, tap again, that's it. Basically never errors out, and it comes in handy in a keyboard only workflow. 

Supports quantization, GPU acceleration, model selection, languages, etc.

One command install and uninstall, and the CLI handles everything. 

UX for Linux is peak.

<p align="center">
  <a href="https://github.com/rccyx/asryx">
    <img src="./assets/asryx.gif" alt="asryx demo" width="100%">
  </a>
</p>


### [thyx](https://github.com/rccyx/thyx) (Λ)

A QML based SDDM login screen, with video backgrounds, fingerprint authentication support, and a composable design system.

Composable as in, you can configure it to your liking. 

It ships with a bunch of presets in case you want to plug in right away or take inspiration from. If you don't like them, make your own.

Comes with stateful and safe install/uninstall.

<div align="center">
  <video title="demo" src="https://github.com/user-attachments/assets/4e52f9d0-ac04-4167-adfc-d14506e9c59c" width="100%" controls>
    Your browser does not support the video tag.
  </video>
</div>


### [powyx](/packages/powyx) (Λ)

The power menu. One command install/uninstall. Works on any distro as long as you have QML deps.

<div align="center">
  <video title="demo" src="https://github.com/user-attachments/assets/3444d5d2-3ed1-45a0-a5d9-a578ccbc1e42" width="100%" controls>
    Your browser does not support the video tag.
  </video>
</div>


You only configure it once like this (here `~/.config/powyx/powyx.toml`):

```toml
[actions]
lock = "hyprlock"
suspend = "systemctl suspend"
reboot = "systemctl reboot"
shutdown = "systemctl poweroff"

[theme]
confirm = "#E7BE5B" 
```

Although, if you use the [flavors](/packages/flavors/) package, you won't need to manually change colors, it will auto adapt.

### ctrlyx (unreleased) (Λ)

This is the control center. C++23 backend with a QML UI, compiled into a 0.5MB binary. No Electron and no GTK widgets.


<div align="center">
  <video title="demo" src="https://github.com/user-attachments/assets/985d4fb3-2e9d-416d-9fca-b57bf48ebb70" width="100%" controls>
    Your browser does not support the video tag.
  </video>
</div>


<div align="center">
  <video title="demo" src="https://github.com/user-attachments/assets/0c6a3aaf-bd6a-46d8-84ed-f9b1a9836f17" width="100%" controls>
    Your browser does not support the video tag.
  </video>
</div>


You hit a keybind (e.g. `Alt + M`) and it pops up (overlay full screen on Hyprland) instantly: Weather, Wi-Fi, Bluetooth, VPN, focus mode, brightness, volume, CPU, RAM, temps, uptime and every device you're connected to.

One screen with a glassmorphic UI that works on almost any background.

Press `Esc` to close it or click up top.

Also, it delegates to your setup, your scripts/binaries or whatever you already use.

You configure it once. For every control you tell it three things: the command to turn it on, the command to turn it off, and the command to check status. 


### clipyx (unreleased) (Λ)

C++ and QML Wayland clipboard manager and history HUD.

A background watcher captures clipboard entries into a local SQLite database with retention rules, and pressing `Ctrl + X` opens a glassmorphic QML overlay with category tabs (text and images), search filtering, and side-by-side text and image previews.

<div align="center">
  <video title="demo" src="https://github.com/user-attachments/assets/6c104aa8-5f5d-448b-8280-99ce443d1ed3" width="100%" controls>
    Your browser does not support the video tag.
  </video>
</div>



### [totpyx](/packages/totpyx/) (Λ)

Tiny, dependency-free RFC 6238 TOTP generator and strict RFC 4648 Base32 decoder written in Rust with zero third-party crypto dependencies.

Supports `SHA-1`, `SHA-256`, and `SHA-512`, `6`, `7`, or `8` digits, configurable period (default `30s`) and `T0` (default `0`), and `--time <unix>` overrides for reproducing test vectors or debugging clock drift. Usable both as a CLI (`cargo install totpyx`) and as a Rust library (`cargo add totpyx`):

```sh
totpyx JBSWY3DPEHPK3PXP
totpyx JBSWY3DPEHPK3PXP --algo sha256 --digits 8
```

**Zsh functions:** This is used with [this zsh function](/config/zsh/functions/2fa.zsh) that wraps `totpyx`, `pass`, `gpg`, and `fzf` into a self-contained terminal 2FA setup. 

It keeps raw Base32 secrets encrypted at rest in `~/.2fa` pinned to a single provided GPG key fingerprint, validates new seeds through totpyx before saving while suppressing stderr so seeds never leak to the terminal, and auto-pushes encrypted changes if the store is a Git repo. 

Just set your GPG fingerprint at the top of the file, source it, and run tfa to initialize the store, add accounts, or fuzzy-pick an account to copy its live 6-digit code to your clipboard.


### [netkit](/packages/netkit) (Δ)

Unified Linux networking CLI that dispatches other Linux utilities.

Consolidates Wi-Fi management, connected Wi-Fi QR sharing, interface and routing inspection, live bandwidth and per-process traffic monitoring, TCP/UDP socket watching, tcpdump packet header capture, speed and latency diagnostics, DNS queries & local network device discovery into a single CLI.

Not on Cargo. Installed to `~/.local`.


### [syncer](/packages/syncer) (Δ)

Atomic package and machine-state snapshotter.

Captures installed packages and versions across `APT` (manual packages, sources, keyrings, dpkg selections), `mise`, `Cargo`, `npm`/`pnpm`, `pipx`, `uv` tools, `Go`, `rustup`, and `Nix` (plus inventory-only `pip3`, `Snap`, `Flatpak`, and GNOME media-key bindings) into an atomic `sync.lock.json` file (default `~/packages`), auto-committing and pushing when tracked in Git, and replaying the full environment on another machine. Through simple calls:

```sh
syncer backup
syncer status
syncer diff
syncer restore --dry-run
syncer restore
```

### [flavors](/packages/flavors) (Δ)

Dynamic theming engine that renders a single TOML palette and matching wallpaper across every visual surface in the workstation via Jinja2 templates.

Generates synchronized color configs for `ctrlyx`, `dircolors`, `gitconfig`, `hypr`, `lookas`, `mako`, `powyx`, `starship`, `tmux`, and Zsh, rotated on demand with `Alt + R`.

## License

Apache-2.0 © @rccyx
