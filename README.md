<h1 align="center">osyx</h1>

<p align="center">
  <a href="https://github.com/rccyx/osyx/actions"><img src="https://img.shields.io/github/actions/workflow/status/rccyx/osyx/ci.yml?style=for-the-badge&color=black&labelColor=111111&logo=githubactions&logoColor=white" alt="CI Status"/></a>
  <a href="https://www.debian.org/releases/trixie/"><img src="https://img.shields.io/badge/Base-Debian_Trixie-black?style=for-the-badge&color=black&labelColor=111111&logo=debian&logoColor=white" alt="Base: Debian Trixie"/></a>
  <a href="https://github.com/rccyx/osyx"><img src="https://img.shields.io/github/repo-size/rccyx/osyx?style=for-the-badge&color=black&labelColor=111111&logo=github&logoColor=white" alt="Size"/></a>
  <a href="https://github.com/rccyx/osyx/blob/main/LICENSE"><img src="https://img.shields.io/badge/License-Apache-black?style=for-the-badge&color=black&labelColor=111111&logo=apache&logoColor=white" alt="License"/></a>
</p>

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/fbd42023-8349-4f86-8bca-e136d4684a56" />

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/56449dd3-0939-4a28-93df-03fe38159e04" />

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/bc9208f7-a41e-4657-8449-ad73ab258a01" />

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/0b2b6556-4547-47ba-9269-a7c5ae7cca63" />

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/1be3fa5e-b7e1-46e5-8ae4-3c3567926be7" />


### Demo

<div align="center">
  <video src="https://github.com/user-attachments/assets/2dfe5dcd-08f7-4e5f-8802-9f6263ede7f9" width="100%" controls>
    Your browser does not support the video tag.
  </video>
</div>

## Explainer

This project is a reproducible Linux user space environment built from a [bare Debian](./provisioning/bootstrap) substrate upward.

Bare Debian as in, starts off without even having `sudo`, plain blank TTY. I broke down why I chose Debian [here](./docs/philosophy.md#model).

I want my rig to behave like a hardened HUD, and still look premium.

A staged layer, provisioning scripts, generated configs, custom tools, cohesive theming, and CI verification checks that turn a blank TTY only Debian install into a keyboard driven workstation.

What they say? Good design is invisible, right?

The problem with modern consumer interfaces is they're built for passive consumption, bloated, icons everywhere, flashy drop downs/apps, 55 choices to click on, and so on. All draining your cognitive bandwidth.

Here, all that is nuked, all of it. Not even the top bar survived, and [here's why](#jarvis-unreleased).

This is still WIP though, but currently it's actually pretty workable.

And I'm slowly open sourcing the entire system in layers.

There isn't a one command install yet, but I'm working on it so it provisions everything in minutes from anywhere.

Currently the [bootstrap](/provisioning/bootstrap) sets up the initial things.

It runs the fresh stage as root and pulls down the absolute vitals like network managers, core utilities, sudo, etc. Then the next stage takes over as the normal user. It wires up audio, video, and input groups, installs the desktop base, swaps shell to Zsh, and starts off all the runtime setups for Rust, Node, Go, and whatever else that installs from those.

It basically builds the entire foundation for the next phase, which is the substrate for the UI, which is the hyprland builder, which is still private.

I have a private repo where it compiles the window manager using a custom builder for Debian from source. It works perfectly, but not open sourced yet as it undergoes more CI checks. Will be merged here when it's stable.

Speaking of CI checks, this is unheard of.

The installers you'll find for Debian usually come with so much bloat and barely tested. May work, may not, please submit an issue, and wait. So everything here is CI/CD tested into oblivion and only builds exactly what it needs to be built.

When this is done, basically all you need is a USB stick and `curl`.

You run it, and minutes later a completely empty machine morphs into this exact hyper optimized workstation.

Totally disposable, and reproducible. No ISO needed.

Speaking of which, everyone calls anything a distro these days.

Also, this project is not dots. Dotfiles imply a bunch of config files that may or may not work, usually an enormous set of files that look intimidating, but don't really do much by themselves, and don't talk to each other. No cohesion whatsoever.

You'd see Alacritty, Ghostty, and Kitty configs, but none of them is slightly workable or even fits the other programs. i3 and Hyprland in the same dump, makes no sense.

My private setup is further ahead, and I'm busy, so parts only become public when they're stable and tested enough, which takes a little bit of time. I can't release something half portable. So when something is public, it's tested thoroughly and documented enough that you can fork it, use it, or fix it yourself.

For example, [thyx](https://github.com/rccyx/thyx) existed since 2024, but was only open sourced in June 2026.

The current repo is mostly the visual setup for now. If you have the core programs like Hypr, tmux, starship etc, you can achieve the exact same look as the demos.

But still, it exposes the portable surface, that I'll keep adding to:

```text
config/        dots, the directory mirror for `~` configuration files
packages/      standalone tools/modules, if they get too big they become a separate repo
provisioning/  bootstrap, runtime, app, and setup scripts
assets/        demos, screenshots, gifs, etc
docs/          usage, stack, workflow, and component documentation
.github/       CI, repo checks, image builds, and automation
```

Pure dotfiles are under [config/](./config). Although, the surface area for dots here is tiny, and many files are generated by the auto flavoring setup. So you might want to read the

## Docs

Dig through:

- [Starting](./docs/starting.md) (The eye candy? Instant theme switching, Hyprland, etc.)
- [Stack](./docs/stack.md) (What's used here?)
- [Philosophy](./docs/philosophy.md) (Why?)

## Custom Tools

These are standalone tools written from scratch, that can be airdropped into any distro.

### [lookas](https://github.com/rccyx/lookas)

A terminal audio visualizer built around human auditory perception. You're probably familiar with CAVA. This is different. It moves beyond raw FFT twitchiness using Mel scaling and spring damper physics.

```sh
cargo install lookas && lookas
```

<p align="center">
  <a href="https://github.com/rccyx/lookas">
    <img src="./assets/lookas.gif" alt="Demo" width="100%">
  </a>
</p>

### [asryx](https://github.com/rccyx/asryx)

Pure C++ voice to text binary for Linux, done the UNIX way. No dependencies beyond the standard C++ and Linux toolchain.

It links to GGML Whisper (local), records through the active Linux audio stack, transcribes locally, copies the output, notifies the session, and exits.

Tap once, speak for as long as you want, tap again, that's it. Basically never errors out, and it comes in handy in a keyboard only workflow. Supports 99 languages through the model weights.

One command install/uninstall, and the CLI handles everything. UX for Linux is peak.

<p align="center">
  <a href="https://github.com/rccyx/asryx">
    <img src="./assets/asryx.gif" alt="Demo" width="100%">
  </a>
</p>

### [thyx](https://github.com/rccyx/thyx)

A QML based SDDM login screen with video backgrounds, fingerprint authentication support, and a composable design system.

Composable as in, you can configure it to your liking, although it ships with a bunch of presets in case you want to plug in right away. If you don't like them, make your own and it'll still look good.

Comes with stateful and safe install/uninstall of course.

<div align="center">
  <video title="demo" src="https://github.com/user-attachments/assets/4e52f9d0-ac04-4167-adfc-d14506e9c59c" width="100%" controls>
    Your browser does not support the video tag.
  </video>
</div>

### Jarvis (Unreleased)

Now here's the thing, the workflow is split between global keybinds and the CLI. No start menus, dropdowns, or clickable icons needed:

- **Chrome:** Alt + G
- **Obsidian:** Alt + O
- **Files (Nautilus):** Alt + F
- **Audio Transcription:** Alt + W
- **Power Menu:** Alt + P
- **Lock:** Alt + L
- **Themes:** Alt + R
- **Clipboard Menu:** Ctrl + X

And so on, till the keys run out.

But the prime real estate ran out a long time ago, so the CLI handles the rest.

That's [Jarvis](https://en.wikipedia.org/wiki/J.A.R.V.I.S.).

Most tasks are handled through the CLI with `fzf` autocompletion, as there's only so much one can remember.

This includes everything from simple brightness adjustments, encryption, 2FA codes, network management, cloud analysis, reminders, syncing packages across Rust, TypeScript, Go, Python, APT, and whatever else, to Git ops, pull request management, reviews, submits, theming, ISO flashing, video editing, audio routing, and much more.

It covers basically anything that doesn't really require a full blown GUI to use. Which if you think about it, what does really require a full blown GUI?

But, speaking of GUIs:

Apps behave like native apps. For example, `app sc` launches SoundCloud, with Hyprland: `Super + F` for fullscreen, and `Super + Q` to quit. It's significantly faster than fumbling with browser tabs and saves seconds of friction every time.

All programs launch in their correct workspaces on boot. Hit the power button, wait for boot, tap the fingerprint sensor, and everything spawns up instantly. No action needed. `Super + 3`, three terminals already open, tmux'ed sessions on the right one, the [visualizer](https://github.com/rccyx/lookas) on the bottom right, and a misc terminal on the top right.

Workspaces are always in the same position. They never change. `Super + 1` is workspace one, always notes. `Super + 9` is reserved for background focus sounds with `app yt` (YouTube). To move laterally, `Alt + Ctrl + Arrows`.

The CLI is the system control layer, and it's what makes this setup usable as a workstation.

A headless control center built to reduce the GUI footprint to the browser, the editor, and the few surfaces that really need those pixels.

You may have noticed that none of the demos have a top/status bar. A top bar is basically redundant here, and a distraction for peak focus.

One thing worse than bloated Electron apps eating RAM is interrupting my focus with unnecessary data.

Starship already tells time. Event driven notifications surface critical system vitals.

Why would I watch the battery sit at 97%? Keep getting anxious when it'll be 55% or lower? The internet always works, and even if it cuts out, I get notified. Battery too. 50%, 33%, 25%, then 20, 15, 10, 5 all get notified. Same with thermals, machine normally stays within a threshold, if it climbs past that, I get notified.

Everything that needs to be seen surfaces only when it needs to be seen.

Why would I need to know which workspace I'm in? I just know. `Super + 1` is notes, `Super + 2` is the browser. Never changes. A workspace indicator is redundant.

Weather? I'd have to set up an API. Plus, I have my phone right next to me, and even if not, I can just feel the weather.

Why would I have a calendar in my tray? I use Google Calendar. Why would I have some random GUI that doesn't even link to anything? Can you book meetings on it? No. So `app cal` Google calendar launches as a native app.

The way these events are set is using idempotent scripts. All encapsulated scripts or programs that can be applied or destroyed.

Usually, to set these things up, you'd have to do step 1, step 2, step 3. Do this in systemd, do that here, copy this, etc. Manual editing/wiring.

Here, you either apply or destroy, just like Terraform.

My philosophy here is basically, if something can be a command, it should be a command.

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

## And more...

There's more to come. For example, a power menu, etc.

## License

Apache-2.0 © @rccyx
