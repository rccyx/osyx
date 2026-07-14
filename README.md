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

<p align="center"><i>Everything visual here, the compositor, theming, tmux, the login, etc, is already open source. The private backend pieces are covered below.</i></p>

## Demo

<div align="center">
  <video src="https://github.com/user-attachments/assets/2dfe5dcd-08f7-4e5f-8802-9f6263ede7f9" width="100%" controls>
    Your browser does not support the video tag.
  </video>
</div>

> [!IMPORTANT]
> This is not a distro, nor a pile of dots. No one command install yet, but, you can already pull individual pieces (the theming setup, the login screen, the standalone tools) and run them today. See [Can I use this today?](#can-i-use-this-today)

## TL;DR

This project is a reproducible Linux user space environment, built from a [bare Debian](/provisioning/bootstrap) substrate upward.

Bare Debian as in, starts off without even having `sudo`, plain blank TTY. I broke down why I chose Debian [here](./docs/philosophy.md#model).

I wanted something that behaves like a hardened HUD, but keeps a premium aesthetic.

### Layers

The system builds itself in layers so it stays incredibly lightweight, bloat free, and completely reproducible:

Provisioning scripts, generated configs, custom tools, cohesive theming, and CI verification checks turn a blank TTY all into a keyboard driven workstation.

### Design

Good design is invisible.

The problem with modern consumer interfaces is they're built for passive consumption and generic consumer convenience:

Bloated menus, icons everywhere, flashy drop downs and apps, 55 choices to choose from, and so on. All to guide a standard user.

Here, all that is nuked, all of it. Not even the top bar exists, and [here's why](#no-top-bar-and-why).

### WIP

This is still WIP, but currently it's actually pretty workable.

I'm slowly open sourcing the entire system.

There isn't a one command install yet, but I'm working on it so it provisions everything in minutes, from anywhere.

### How the bootstrap works

Currently the [bootstrap](/provisioning/bootstrap) sets up the initial things.

It runs the fresh stage as root and pulls down the absolute vitals like network managers, core utilities, sudo, etc.

Then the next stage takes over as the normal user. It wires up audio, video, and input groups, installs the desktop base, swaps the shell, and starts off all the runtime setups for Rust, Node, Go, and whatever else needs to install from those.

It builds the entire foundation for the next phase, which is the substrate for the UI, which is the Hyprland builder, which is still private.

### Future vision

When this is done, basically all you need is a USB stick and `curl`.

You run it, and minutes later a completely empty machine morphs into this exact hyper optimized workstation.

Totally disposable, and reproducible. No ISO needed.

### ISOs, Dots issue & custom tooling

Everyone calls anything a distro these days.

Also, this project isn't dots.

Dotfiles imply a bunch of config files that may or may not work.

Usually, it's an enormous set of files that look intimidating, but don't really do much by themselves, and don't talk to each other.

You'd have these Frankenstein repos that barely work on the creator's machine, let alone yours, and they're only good for screenshots. There's no cohesion whatsoever. You'd see Alacritty, Ghostty, and Kitty configs, but none of them is slightly workable or even fits the other programs.

Here, if a program doesn't fit, I just make a custom made one that's just suited for this whole setup.

For example, CAVA is too twitchy for the frequency visualizer. So I built my own custom visualizer that fits how humans hear sound, not twitchy.

I also have my own Hyprland builder. Why? Because the current ecosystem doesn't have a good Hyprland builder, it's either bloated or bloated.

Same for the login theme. And so on.

### Private -> Public

My private setup is further ahead, and I'm busy, so parts only become public when they're stable enough, which takes a little bit of time. I can't release something half portable. So when something is public, it's tested thoroughly and documented enough that you can fork it, use it, or fix it yourself.

For example, [thyx](https://github.com/rccyx/thyx) existed since 2024, but was only open sourced in June 2026 when I got the CI/CD matrix to work on Arch, Debian, Nix, Fedora, and more.

## Stack

These basically never change, only updated when it makes sense.

| Layer                | What                                                                           |
| -------------------- | ------------------------------------------------------------------------------ |
| Distro               | Debian `v13`                                                                   |
| Display              | Wayland `v1.24.0`                                                              |
| Compositor           | Hyprland `v0.53.3`, built from `main`                                          |
| Lockscreen           | Hyprlock `v0.9.5`                                                              |
| Terminal             | Kitty `v0.41.1`                                                                |
| Multiplexer          | Tmux `v3.5a`                                                                   |
| Shell                | Zsh `v5.9` + Starship `v1.23.0` + Lsd `v1.1.5`                                 |
| Notifications        | Mako `v1.10.0-1`                                                               |
| Launcher / Clipboard | Wofi `v1.4.1` (UI), custom backend                                             |
| Fonts                | Inter (sans), Iosevka (mono), Meslo (Nerd Font fallback), Jakarta Sans (login) |
| Audio                | PipeWire `v1.4.2`                                                              |
| Login                | [thyx](https://github.com/rccyx/thyx)                                          |

_...and more private utilities. Full version pins and commit hashes are in [stack.md](./docs/stack.md)._

## Can I use this today?

Yes you can.

You can use pieces of it.

The full public one command install is not available yet, so the way to go by this right now is component extraction: grab what you want, wire it into your own setup.

If you already have the core programs like Hypr, tmux, starship, etc, you can achieve the exact same look as the demos.

Still, the repo exposes the portable surface, that I'll keep adding to:

```text
osyx/
├── bin/            standalone CLI utilities: battery, wifi, brightness, app launcher, and so on
├── config/         dotfiles, mirrors ~ directly
├── packages/       standalone tools and package like modules (the flavors engine, power menu, hypr builder, etc)
├── provisioning/   bootstrap, runtimes, apps, and setup scripts
├── assets/         demos, screenshots, gifs
├── docs/           usage, stack, workflow, and component documentation
└── .github/        CI, repo checks, image builds, and automation
```

Pure dotfiles are under [config/](./config), although the surface area for dots here is tiny, and many files are generated by the auto flavoring setup.

Mako for example is entirely auto generated, while Hyprland only reads an auto generated `theme.conf` while the rest is static.

## Docs

Dig through:

- [Starting](./docs/starting.md) (The eye candy? Instant theme switching, Hyprland, etc.)
- [Stack](./docs/stack.md) (What's used here?)
- [Philosophy](./docs/philosophy.md) (Why?)

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

It links to GGML Whisper (local), records through the active Linux audio stack, transcribes locally, copies the output, notifies the session, and exits.

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

## Jarvis (Unreleased)

The workflow is split between global keybinds and the CLI. No start menus, dropdowns, or clickable icons needed:

### The keybinds

| Bind       | Action              |
| ---------- | ------------------- |
| `Alt + G`  | Chrome              |
| `Alt + O`  | Obsidian            |
| `Alt + F`  | Files (Nautilus)    |
| `Alt + W`  | Audio Transcription |
| `Alt + P`  | Power Menu          |
| `Alt + L`  | Lock                |
| `Alt + R`  | Themes              |
| `Ctrl + X` | Clipboard Menu      |

And so on, till the keys run out.

### The CLI

The CLI is the system control layer, and it's what makes this setup usable as a workstation.

You saw the keybinds, but the prime real estate ran out a long time ago, so the CLI handles the rest. That's [Jarvis](https://en.wikipedia.org/wiki/J.A.R.V.I.S.).

Most tasks are handled through `fzf` autocompletion, as there's only so much one can remember.

This includes everything from encryption, 2FA codes, network management, cloud analysis, reminders, syncing packages across Rust, TypeScript, Go, Python, APT, and whatever else, to Git ops, pull request management, reviews, submits, ISO flashing, video editing, audio routing, and much more.

It covers basically anything that doesn't really require a full blown GUI to use. Which if you think about it, what does really require a full blown GUI?

But, speaking of GUIs: apps behave like native apps. For example, `app sc` launches SoundCloud, with Hyprland: `Super + F` for fullscreen, and `Super + Q` to quit. It's significantly faster than fumbling with browser tabs and saves seconds of friction every time.

### Boot to desktop

All programs launch in their correct workspaces on boot. Hit the power button, wait for boot, tap the fingerprint sensor, and everything spawns up instantly. No action needed. `Super + 3`, three terminals already open, tmux'ed sessions on the right one, the [visualizer](https://github.com/rccyx/lookas) on the bottom right, and a misc terminal on the top right.

### Workspaces never move

Workspaces are always in the same position. They never change. `Super + 1` is workspace one, always notes. `Super + 9` is reserved for background focus music with `app yt` (YouTube). To move laterally, `Alt + Ctrl + Arrows`.

### No top bar, and why

You may have noticed that none of the demos have a top or status bar. A top bar is basically redundant here, and a distraction for peak focus.

One thing worse than bloated Electron apps eating RAM is interrupting my focus with unnecessary data.

Starship already tells time. Event driven notifications surface critical system vitals.

Why would I watch the battery sit at 97%? Keep getting anxious when it'll be 55% or lower? The internet always works, and even if it cuts out, I get notified.

Battery for example, I get notified at 50%, 33%, 25%, 15%; 10%, 5%. Same with thermals, machine normally stays within a threshold, if it climbs past that, I get notified.

**Everything that needs to be seen surfaces only when it needs to be seen.**

Why would I need to know which workspace I'm in? I just know. `Super + 1` is notes, `Super + 2` is the browser. Never changes. A workspace indicator is redundant.

Why would I have a calendar in my tray? I use Google Calendar. Why would I have some random GUI that doesn't even link to anything? Can you book meetings on it? No. Does it have years of data on it? No. So `app cal` launches Google Calendar as a native app.

### Idempotent by design

The way these events are set is using idempotent scripts. All encapsulated scripts or programs that can be applied or destroyed.

Usually, to set these things up, you'd have to do step 1, step 2, step 3. Do this in systemd, do that here, copy this, etc. Manual editing, which is error prone and wastes time.

Here, you either apply or destroy, just like Terraform.

**If something can be a command, it should be a command.**

### Why Jarvis?

I called it Jarvis because my vision is that I can finally ditch the keyboard for redundant work, and don't have to think about how to use a computer. The computer just bends to human thoughts instantly.

```text
Hey Jarvis, connect to Oslo.
No, Bucharest.

Sync all packages across pipx, cargo, npm, apt, and Go.
Do we even have Go?
Long time no see.
Go too. All runtimes please.

Clean up these Docker volumes.

Flash this ISO.

Actually, upload this to S3 first.
Wait, what's my AWS cost for the month?
Check eu-central-1 and us-east-1.

Show me all events from last Tuesday between 2:00 PM and 4:00 PM.
Bridge that to EventBridge.

What's on my reminders?

What's the 2FA code for GitHub?

Record this video.
Route audio through Vocaster, not the default sink.
Cut it from second 6 to 45.

Notify me in 6 hours.

Run OCR on this PDF.
Name it YYYY-MM-DD-NAME-FINAL.pdf.
Send it.

Hibernate now.
```

I genuinely don't like typing.

## License

Apache-2.0 © @rccyx
