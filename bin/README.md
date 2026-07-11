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

`./battery` reads battery, charging, capacity, and health information directly from Linux power supply data.

```bash
battery # Displays the current level, power source, status, and health
```

Uses standard `bash`. No external dependencies.
