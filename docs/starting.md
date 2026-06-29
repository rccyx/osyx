# Starting

So you're probably wondering can I use this? Or, how do I make my setup look like that?

You can use pieces of it today.

BUT: The full public one command install is not available yet, so the way to approach this is component extraction.

## What you're looking at

There is no desktop environment. You boot in, Hyprland starts, and Hyprland is empty. No panels, no app launchers, no system tray. Just a tiling window manager. The desktop is whatever you launch into it.

What makes it look the way it does in the demos is entirely these programs working together.

1. [Fonts](./ui/fonts.md)
2. [Flavors](./ui/flavors.md)
3. [Zsh](./ui/zsh.md)
4. [Starship](./ui/starship.md)
5. [Tmux](./ui/tmux.md)
6. [Dircolors](./ui/dircolors.md)
7. [Hyprland](./ui/hypr.md)
8. [Mako](./ui/mako.md)
9. [Wofi](./ui/wofi.md)
10. [Neovim](./ui/nvim.md)

You may have seen me switch themes instantly, to get that, check the [flavors](./ui/flavors.md) docs.

## The rule

This repo mirrors my real working setup, but the public repo only exposes the parts that are safe enough to share.

The convention is:

```text
normal files      portable layer
underscore files  personal layer
generated files   output layer
```

Normal files are meant to be copied directly.

Underscore files are real workflow files, but they may contain my monitor names, my weird keyboard layout, app paths, startup layout, local binaries, generated paths, hardware assumptions, or personal keybinds, etc.

Example from Hyprland:

```text
hyprlock.conf     totally portable

_keybinds.conf     personal
_startup.conf      personal
_variables.conf    personal
_clipboard.conf    generated / machine-local
```

The root `config/` folder maps directly to `~`. So `config/.config` is `~/.config/` and shell dotfiles like `config/.zshrc` map to `~/.zshrc`.

Some surfaces:

```text
config/zsh/                shell modules
config/.gitconfig          git entry config
config/.gitconfig.d/       git modules
config/.config/hypr/       Hyprland compositor config
config/.config/kitty/      terminal config
config/.config/nvim/       Neovim config
config/.config/swappy/     screenshot annotation
...
```

> [!IMPORTANT]
> Generated files are written by [scripts](./ui/flavors.md). Edit the source that generates them.

## What to copy first

### 1. Fonts

[fonts.md](./ui/fonts.md)

The font setup installs Inter, Iosevka Fixed SS18, and Meslo, then Fontconfig routes them correctly so browsers, terminals, notifications, launchers, and glyphs render the same way.

### 2. Flavors

[flavors.md](./ui/flavors.md)

Flavors is the palette theme switcher.

One palette changes Starship, Tmux, Hyprland borders, Mako, Wofi, Dircolors, Neovim, Git output, and the wallpaper.

And the way it works is this:

```text
palette TOML
  ↓
generator
  ↓
Jinja templates
  ↓
generated config files
  ↓
live reload
```

### 3. Zsh

[zsh.md](./ui/zsh.md)

Zsh is the shell loader.

It wires the environment, tool integrations, Starship, Flavors, and personal shell state.

### 4. Starship

[starship.md](./ui/starship.md)

Starship is the prompt layer.

It carries the state that a top bar usually wastes space showing: time, directory, Git state, runtime state, and command result.

### 5. Tmux

[tmux.md](./ui/tmux.md)

Tmux is the persistent terminal workspace.

The status bars on the bottom of the terminal are tmux windows.

### 6. Dircolors

[dircolors.md](./ui/dircolors.md)

Dircolors controls file colors through `LS_COLORS`.

It keeps terminal listings visually aligned with the active palette.

### 7. Hyprland

Read [hypr.md](./ui/hypr.md)

### 8. Mako and Wofi

[mako.md](./ui/mako.md)
[wofi.md](./ui/wofi.md)

Mako is notifications.

Wofi is launcher and picker surface.

### 9. Neovim

[nvim.md](./ui/nvim.md)

Neovim is optional.

## Repo map

The repo is now split by purpose. `config/` is the home-directory mirror; packages and provisioning live outside that mirror.

```text
config/        user-space configs that map into ~
packages/      standalone tools and package-like modules
provisioning/  bootstrap, runtime, app, and setup scripts
assets/        screenshots and gifs
.github/       CI and repo checks
docs/          documentation
```
