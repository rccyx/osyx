# Hyprland

Repository entry point:

```text
config/.config/hypr/hyprland.lua
```


Installed entry point:

```text
~/.config/hypr/hyprland.lua
```

`hyprland.lua` contains no compositor configuration of its own. It is only the entry point and owns the module load order.

The configuration is split into focused Lua modules. Each file documents its own purpose, settings, dependencies, and machine-specific assumptions.

