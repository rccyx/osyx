# bin

To run these binaries globally from any directory, move this `/bin` folder to `~` if not bootstrapped there already.

The [`~/.zshrc`](/config/.zshrc) file already sets this up and automatically makes any new binary at `~/bin` executable.

## Bins

**wallpaper:**

`./wallpaper` depends on `waypaper >= v2.6`, `swww >= 0.10.3-master`.

```bash
wallpaper # Opens the Waypaper GUI (wallpapers should be inside `~/.wallpapers`)
wallpaper set <f> # Sets desktop to a specific image file
wallpaper random # Applies a random wallpaper from your folder
```

Uses standard `bash`.

**battery:**

`./battery` reads battery, charging, capacity, and health info.

```bash
battery
```

Uses standard `bash`. No external dependencies.

**keyboard:**

`./keyboard` changes the system keyboard layout and applies it immediately to the current session when available.

```bash
keyboard fr # French
keyboard us # English US
keyboard de # German
keyboard gb # English UK
keyboard us intl # English US International
keyboard fr bepo # French Bépo
```

Accepts any valid XKB layout and optional variant.

Uses standard `bash`. Depends on `localectl`, `sudo`, and `hyprctl` when running inside Hyprland.

**diskspace:**

`./diskspace` displays the total, used, and available disk space for the home filesystem.

```bash
diskspace
```

Uses standard `bash`. No external dependencies.

**diskusage:**

`./diskusage` opens an interactive disk usage analyzer for the full filesystem.

```bash
diskusage
```

Uses standard `bash`. Depends on `dua >= v2.31.0`.

**heat:**

`./heat` reads the current CPU temperature (in Celsius) directly from Linux hardware monitoring data.

```bash
heat
```

Uses standard `bash`. No external dependencies.

**suspend:**

`./suspend` suspends the machine.

```bash
suspend
```

Just a `systemctl suspend` alias.

**hibernate:**

`./hibernate` hibernates the machine.

```bash
hibernate
```

Just a `systemctl hibernate` alias.
