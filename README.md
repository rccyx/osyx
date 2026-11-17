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
    <td><img width="100%" alt="osyx desktop" src="https://github.com/user-attachments/assets/e0ad8df6-758b-4f8b-bed9-fd262a7306ce" /></td>
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

Not dots (included anyway), nor a distro (anything is a distro these days). 

Starting with bare Debian (Trixie) for now, and extending to others in the future (Arch, etc). 

Which converts a blank TTY into a hyper optimized and premium looking workstation in minutes.

Everything is built/assembled from scratch (base slate doens't even include `sudo`), and to make it all cohesive: the login screen, the power menu, the theming, everything, even the Hyprland builder (compiles all hypr programs for Debian) work together in unison.  

If a program doesn't fit, I just make a custom made one that's suited.

It gives a pristine, premium feel of macOS built on 100% open-source software.

It's been my daily driver for years at this point. Excellent for engineering, it doesn't brick on Monday mornings, it just works and looks good. 

I haven't touched macOS/Windows in years.

Recently, I started open-sourcing this whole setup, so I'm dropping projects one by one.

## Product

I want my experience to operate like a HUD, but also look beautiful.

I have an issue with bloated menus, icons everywhere, flashy drop downs, too many built in apps, choice fatigue, etc.

So, everything in here only surfaces when you actually need to see it. Even the top bar is gone.

The system builds itself layer by layer. 

When it builds, it's lightweight, bloat-free, and completely reproducible and extendable.


### Zero cognitive pollution

**On-demand metrics:** Vitals surface only when you need to them: Notifications show alerts only when the battery hits 50%, 33%, 25%, 15%, 10%, and 5%. If thermals spike or network drops, the system auti-notifies you.

Need time or system status? Hit `Alt + M` to invoke the control center or check Starship in your terminal. Otherwise, the desktop is completely empty.

There's not even a workspace indicator: `Super + 1` is always workspace one (Obsidian). `Super + 2` is always 2 and so on (browser). `Super + 3` is always terminal. 

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

Slowly releasing this since I need time to decouple from my personal setup.

It covers basically anything that doesn't really require a full blown GUI to use.

Which if you think about it, what does really require a full blown GUI?

### Apps

Apps behave like native apps. For example, `app sc` launches SoundCloud, `app yt` for YouTube, with Hyprland: `Super + F` for fullscreen, and `Super + Q` to quit. It's significantly faster than fumbling with browser tabs and saves seconds of friction every time.

## Custom Tooling

These are my custom programs:

| Package | Written | Description |
| :--- | :--- | :--- |
| **[`asryx`](https://github.com/rccyx/asryx)** | C++ | Offline, daemonless voice-to-text CLI (GGML Whisper + Silero VAD). Zero idle RAM. |
| **[`lookas`](https://github.com/rccyx/lookas)** | Rust | Auditory-perceptual audio visualizer using Mel scaling & spring damper physics. |
| **[`thyx`](https://github.com/rccyx/thyx)** | QML | Atomic SDDM login screen with video backgrounds and PAM fingerprint auth. |
| **[`powyx`](/packages/powyx)** | QML / Shell | Zero-overhead power menu HUD (`lock`, `suspend`, `reboot`, `shutdown`). |
| **`ctrlyx`** | C++ / QML | Daemonless control center HUD for hardware stats, weather, network management, and more. |
| **[`flavors`](/packages/flavors)** | Python | Dynamic color engine that generates matching themes across the desktop/login |
| **[`hyprtryx`](/packages/hyprtryx)** | Shell / Make | Bare-metal builder compiling Hyprland (`v0.56+`) and the hypr ecosystem dependencies from source on Trixie. |

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
| Launcher / Clipboard | Wofi `v1.4.1` (UI), custom backend |
| [Fonts](https://github.com/rccyx/osyx/releases/tag/fonts-v1.0.0) | Inter (sans), Iosevka (mono), Meslo (Nerd Font fallback), Jakarta Sans (login) |
| Audio | PipeWire `v1.4.2` |

## Bootstrap

Have a look at this [CI workflow](./.github/workflows/on-workflow-call-bootstrap.yml).

The bootstrap process is like this:

| Stage | Name | What it does |
| :--- | :--- | :--- |
| 0 | Root Bootstrap | Boots a fresh Debian install (bare metal). Sets up network interfaces, core system packages, user privileges, and atomic state directories. |
| 1 | User Bootstrap | Configures user groups (audio, video, input, etc), installs base display libraries, sets Zsh as default shell, and provisions language runtimes/package managers (rust, node, go, uv, etc). |
| 2 | Hyprland/Wayland | Invokes hyprtryx to compile the visual desktop so we exit the TTY gulag, Wayland protocols, and dependencies natively for the host CPU architecture. |
| 3 | Workstation Layer | Provisions custom binaries (asryx, thyx, lookas, powyx, etc), generates global visual themes via flavors, and hooks up event notifications. |

Mind you, this is Debian, the hyprland builder is able to build Hyprland from source (and the related hypr projects like hyprlock, hyprsunset, etc.).

### Future Vision

When this is done, basically all you need is a USB stick with a bare metal distro and `curl`.

You Jason Bourne with one command, and minutes later a completely empty machine morphs into this exact hyper optimized workstation.

Totally disposable and reproducible. **No ISO needed.**

## Can I use this today?

Yes. 

Thre's no one command install yet, so the way to go by this right now is component extraction. 

Just grab what you want & wire it into your own setup.

```
osyx/
├── bin/            # Standalone CLI tools (battery, wifi, brightness, sound, heat)
├── config/         # System dotfiles (~/.config mirrors)
├── packages/       # Standalone tools (asryx, thyx, lookas, powyx, flavors, hyprtryx)
├── provisioning/   # Bootstrap, runtime setups, and app provisioners
└── docs/           # Docs
```

Read the [docs](/docs/starting.md).

## Custom Tools

Standalone tools written from scratch. Can be airdropped into any distro.

### [lookas](https://github.com/rccyx/lookas)

A terminal audio visualizer built around human auditory perception. It moves beyond raw FFT twitchiness using Mel scaling and spring damper physics.

```sh
cargo install lookas && lookas
```

<p align="center">
  <a href="https://github.com/rccyx/lookas">
    <img src="./assets/lookas.gif" alt="lookas demo" width="100%">
  </a>
</p>

### [asryx](https://github.com/rccyx/asryx)

Pure C++ voice to text binary for Linux, done the UNIX way. No dependencies beyond the standard C++ and Linux toolchain.

It links to GGML Whisper (100% offline), records through the active Linux audio stack, transcribes locally, copies the output, notifies the session, and exits.

Tap once, speak for as long as you want, tap again, that's it. Basically never errors out, and it comes in handy in a keyboard only workflow. 

One command install and uninstall, and the CLI handles everything. 

UX for Linux is peak.

<p align="center">
  <a href="https://github.com/rccyx/asryx">
    <img src="./assets/asryx.gif" alt="asryx demo" width="100%">
  </a>
</p>

### [thyx](https://github.com/rccyx/thyx)

A QML based SDDM login screen, with video backgrounds, fingerprint authentication support, and a composable design system.

Composable as in, you can configure it to your liking. 

It ships with a bunch of presets in case you want to plug in right away or take inspiration from. If you don't like them, make your own, and it will still look good.

Comes with stateful and safe install/uninstall.

<div align="center">
  <video title="demo" src="https://github.com/user-attachments/assets/4e52f9d0-ac04-4167-adfc-d14506e9c59c" width="100%" controls>
    Your browser does not support the video tag.
  </video>
</div>


### [powyx](/packages/powyx)

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

### ctrlyx (unreleased)

This is the control center. C++23 backend with a QML UI, compiled into a 0.5MB binary. No Electron and no GTK widget.


<div align="center">
  <video title="demo" src="https://github.com/user-attachments/assets/985d4fb3-2e9d-416d-9fca-b57bf48ebb70" width="100%" controls>
    Your browser does not support the video tag.
  </video>
</div>

You hit a keybind (i.e `Alt + M`) and it pops up (overlay full screen on Hyprland) instantly: Weather, Wi-Fi, Bluetooth, VPN, focus mode, brightness, volume, CPU, RAM, temps, uptime and every device you're connected to.

One screen with a glassmorphic UI that works on almost any background.

Press `Esc` to close it or click up top.

Also, it delegates to your setup, your scripts/binaries or whatever you already use.

You configure it once. For every control you tell it three things: the command to turn it on, the command to turn it off, and the command to check status. 

## License

Apache-2.0 © @rccyx