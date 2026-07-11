# bin

To run these binaries globally from any directory, move this `/bin` folder to `~`.

The [`~/.zshrc`](/config/.zshrc) file already sets this up and autosources any new binary at `~/bin`.

## Bins

**wallpaper:**

`./wallpaper` depends on `waypaper >= v2.6`, `swww >= 0.10.3-master`.

```bash
wallpaper # Opens the Waypaper GUI (wallpapers should be inside `~/.wallpapers`)
wallpaper set <f> # Sets desktop to a specific image file
wallpaper random # Applies a random wallpaper from your folder
```

Uses standard `bash`.
