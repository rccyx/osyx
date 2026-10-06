<div align="center">

# **_osyx_**

<p align="center"><i>A reproducible, keyboard driven Linux workstation, built from bare Debian upward.</i></p>

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
</table>

<p align="center"><i>The UI in these shots is custom, from the login screen to the power menu to the control center.</i></p>

## Demo

<div align="center">
  <video src="https://github.com/user-attachments/assets/2dfe5dcd-08f7-4e5f-8802-9f6263ede7f9" width="100%" controls>
    Your browser does not support the video tag.
  </video>
</div>

> [!IMPORTANT]
> This is still in beta, there's no one command install yet, but you can already pull individual pieces (the theming setup, the login screen, the standalone tools) and run them today. See [Can I use this today?](#can-i-use-this-today)

## What

This not dots, nor a distro. 

OSyx is a **meta-distro**.


It's a bespoke OS layer that attaches to a clean base OS (starting with bare Debian Trixie for now, and extending to others in the future, Arch, etc.) and converts a blank TTY into a hyper-optimized, premium looking workstation in minutes.

Everything is built/assembled from scratch (the starting base has no `sudo` even), and to make it all cohesive: the login screen, the power menu, the control center, the audio visualizer, the theming engine, even the Hyprland builder. All mine, and all built to fit each other.

It gives you the pristine, premium feel of macOS built on 100% open-source software, with zero Apple bullshit.

It's been my daily driver for years at this point. It doesn't embarrass me in business meetings, excellent for dev work, it doesn't brick on Monday mornings, it just works. I haven't touched macOS/Windows in years.

I recently started open-sourcing this whole setup.

### Why not just dots?

Dotfiles imply a bunch of config files that may or may not work.

Frankenstein repos that barely work (good for screenshots though). You'll see Alacritty, Ghostty, and Kitty configs, but none of them is slightly workable or even fits the other programs.

Here, if a program doesn't fit, I just make a custom made one that's just suited for this whole setup.

For example, CAVA is too twitchy for the frequency visualizer. So I built my own [custom visualizer](#lookas) that fits how humans hear sound.

I also have my own Hyprland builder. Why? Because the current ecosystem doesn't have a good Hyprland builder, it's either bloated or bloated.

This one is CI/CD tested and idempotent.

### Why not a distro?

Anyone calls anything a distro these days, I do think they're a relic from the 2000s. Distro wars don't make sense in 2026.

Anything works, so build on top of it, this does exactly that.

## Philosophy

When it comes to using Linux, there are two basically types of people.

### Ricers

[Ricers](https://reddit.com/r/unixporn) (Aesthetics = 999/10. Reliability = 1/10)

Usually artists, students, or hobbyists, building insanely beautiful masterpieces, but endlessly replacing components, rebuilding configs every month, (actually every week), some even days. And have ABSOLUTELY no problem bricking the daily driver on a Monday morning.

### Hardcore old school setup

[Hardcore old school setup](https://youtu.be/bdumjiHabhQ) (Aesthetics = -1/10. Reliability = 10/10)

Brutally efficient workflows, fast terminals, muxed everywhere, keyboard-driven systems, extremely high throughput for professional work, but the machine itself often looks like an ancient (and hostile) screen from the 80s that no one wants to use. And CANNOT brick the daily driver on a Monday morning.

### The missing 10%

This project combines the best parts of both.

Professionals who demand technical excellence AND aesthetic excellence. 

## Minimalism

The system builds itself in layers so it's incredibly lightweight, bloat free, and completely reproducible.

Also, good design is invisible.

One thing worse than bloated Electron apps eating RAM is interrupting my focus with unnecessary data.

I have a big issue with bloated menus, icons everywhere, flashy drop downs, too many built in apps, 55 choices to choose from, and so on. 

All to guide a standard user.

Here, all that is nuked, all of it. Not even the top bar exists.

**Everything that needs to be seen surfaces only when it needs to be seen.**

### Zero cognitive pollution

This works like an event-driven fighter jet HUD.

For example, vitals surface only when actionable: Notifications alert you when the battery hits 50%, 33%, 25%, 15%, 10%, and 5%. If thermals spike or network drops, the system notifies you.

Watching a battery icon sit at 97%, staring at a clock tick away seconds, or looking at static workspace indicators constantly steals focus and cause anxiety.

**On-demand metrics:** Need time or system status? Hit `Alt + M` to invoke the control center or check Starship in your terminal. Otherwise, the desktop is completely empty and dark.

There's not even a workspace indicator: `Super + 1` is always notes. `Super + 2` is always browser. `Super + 3` is always terminal. Spatial memory makes workspace indicators redundant.

### Keybinds

Almost everything is a keyboard shortcut, no menus.

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

The workflow is split between global keybinds and the CLI. No start menus, dropdowns, or clickable icons needed.

Set up a key and so on, till the keys run out.

But the prime real estate ran out a long time ago, so the CLI handles the rest.

### CLI

Most tasks are handled through `fzf` autocompletion, as there's only so much one can remember.

This includes everything from encryption, 2FA codes, network management, cloud analysis, reminders, syncing packages across Rust, TypeScript, Go, Python, APT, and whatever else, to Git ops, pull request management, reviews, submits, ISO flashing, video editing, audio routing, and much more.

Slowly releasing this since I need time to decouple from my personal setup.

It covers basically anything that doesn't really require a full blown GUI to use.

Which if you think about it, what does really require a full blown GUI?

### Apps

Speaking of GUIs: apps behave like native apps. For example, `app sc` launches SoundCloud, `app yt` for YouTube, with Hyprland: `Super + F` for fullscreen, and `Super + Q` to quit. It's significantly faster than fumbling with browser tabs and saves seconds of friction every time.

## Idempotent Engineering

When you install standard software, stale directories linger deep inside ~/.cache, ~/.config, and /tmp forever. Or when you install a stardard setup, you're forced to use tool possible.

Here, every project under the osyx umbrella follows the Terraform rule: you can either apply or destroy.

Want speech recognition? Install asryx.

Want to remove it? Run the uninstaller. Every single byte is wiped clean as if it was never installed.

Even tools that are not made by me, for example, don't like your hyprland version anymore? Take hyprtryx and run destroy, update the versions of deps & apply again, and reboot.

## Built-In Custom Tooling

`osyx` uses custom native programs engineered AND designed specifically for this setup:

| Package | Language / Tech | Description |
| :--- | :--- | :--- |
| **[`asryx`](https://github.com/rccyx/asryx)** | C++ | Offline, daemonless voice-to-text CLI (GGML Whisper + Silero VAD). Zero idle RAM. |
| **[`lookas`](https://github.com/rccyx/lookas)** | Rust | Auditory-perceptual audio visualizer using Mel scaling & spring damper physics. |
| **[`thyx`](https://github.com/rccyx/thyx)** | QML | Atomic SDDM login screen with video backgrounds and PAM fingerprint auth. |
| **[`powyx`](/packages/powyx)** | QML / Shell | Zero-overhead power menu HUD (`lock`, `suspend`, `reboot`, `shutdown`). |
| **[`ctrlyx`](https://github.com/rccyx/ctrlyx)** | C++ / QML | Daemonless control center HUD for hardware stats, audio, and network management. |
| **[`flavors`](/packages/flavors)** | Python | Dynamic color engine that generates matching themes across the desktop/login |
| **[`hyprtryx`](/packages/hyprtryx)** | Shell / Make | Bare-metal builder compiling Hyprland (`v0.56+`) and the hypr ecosystem dependencies from source on Trixie. |

### Core utilities

| Layer | What |
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
| Fonts | Inter (sans), Iosevka (mono), Meslo (Nerd Font fallback), Jakarta Sans (login) |
| Audio | PipeWire `v1.4.2` |

## Bootstrap

There's a bootstrap setup but still wip, have a look at this [CI workflow](./.github/workflows/on-workflow-call-bootstrap.yml).

The bootstrap process is like this:

| Stage | Name | What it does |
| :--- | :--- | :--- |
| 0 | Root Bootstrap | Boots a fresh Debian install (doesn't even have sudo). Sets up network interfaces, core system packages, user privileges, and atomic state directories. |
| 1 | User Bootstrap | Configures user groups (audio, video, input, etc), installs base display libraries, sets Zsh as default shell, and provisions language runtimes/package managers (rust, node, go, uv, etc). |
| 2 | Hyprland/Wayland | Invokes hyprtryx to compile the visual desktop so we exit the TTY lobby, Wayland protocols, and dependencies natively for the host CPU architecture. |
| 3 | Workstation Layer | Provisions custom binaries (asryx, thyx, lookas, powyx, etc), generates global visual themes via flavors, and hooks up event notifications. |

Mind you, this is Debian, the hyprland builder is able to build Hyprland from source (and the related projects like hyprlock, hyprsunset, etc.).

### My Vision

"Jesus Christ... that's Jason Bourne".

Jason Bourne can walk into an empty room, grab whatever bare-bones hardware is lying around, and instantly turn it into a high-tech tactical command center.

When this is done, basically all you need is a USB stick with a bare metal distro and `curl`.

You run it, and minutes later a completely empty machine morphs into this exact hyper optimized workstation.

Totally disposable and reproducible. **No ISO needed.**

## Can I use this today?

Yes. You don't have to wait for a final automated one-command installer.

The full public one command install is not available yet, so the way to go by this right now is component extraction. 

Just grab what you want & wire it into your own setup.

```
osyx/
├── bin/            # Standalone CLI tools (battery, wifi, brightness, sound, heat)
├── config/         # System dotfiles (~/.config mirrors)
├── packages/       # Standalone tools (asryx, thyx, lookas, powyx, flavors, hyprtryx)
├── provisioning/   # Bootstrap, runtime setups, and app provisioners
└── docs/           # Docs
```

## Custom Tools

These are standalone tools written from scratch, that can be airdropped into any distro.

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

Tap once, speak for as long as you want, tap again, that's it. Basically never errors out, and it comes in handy in a keyboard only workflow. Supports 99 languages through the model weights.

One command install and uninstall, and the CLI handles everything. UX for Linux is peak.

<p align="center">
  <a href="https://github.com/rccyx/asryx">
    <img src="./assets/asryx.gif" alt="asryx demo" width="100%">
  </a>
</p>

### [thyx](https://github.com/rccyx/thyx)

A QML based SDDM login screen, with video backgrounds, fingerprint authentication support, and a composable design system.

Composable as in, you can configure it to your liking, although it ships with a bunch of presets in case you want to plug in right away or take inspiration from. If you don't like them, make your own, and it'll still look good.

Comes with stateful and safe install/uninstall, of course.

<div align="center">
  <video title="demo" src="https://github.com/user-attachments/assets/4e52f9d0-ac04-4167-adfc-d14506e9c59c" width="100%" controls>
    Your browser does not support the video tag.
  </video>
</div>


### ctrlyx

This is the control center. C++23 with a QML UI, compiled into a 0.5MB binary. No Electron and no GTK widget.

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/5c0f9719-132b-433d-8053-b591ca7b3598" />

You hit `Alt + M` and it pops up (overlay full screen on Hyprland) instantly: Weather, Wi-Fi, Bluetooth, VPN, focus mode, brightness, volume, CPU, RAM, temps, uptime and every device you're connected to.

One screen with a glassmorphic UI that works on almost any background.

Press `Esc` to close it or click up top.

#### It follows the Unix philosophy

It delegates to your setup, your scripts, your binaries or whatever you already use.

You configure it once. For every control you tell it three things: the command to turn it on, the command to turn it off, and the command to check status. 

Some things are hardcoded on purpose, like brightness and sound. Those are smooth and automatic, no config needed.

#### Ergonomics

It's built for keyboard-first use. I never use a mouse, so the design follows that: brightness and sound are big pill-shaped sliders on the left, easy to land on and easy to roll with my right thumb.

Way better than fumbling with a tiny window up top or hunting for the F-keys.

## License

Apache-2.0 © @rccyx