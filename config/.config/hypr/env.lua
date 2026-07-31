-- =============================================================================
-- env.lua — Wayland environment and cursor configuration
-- =============================================================================

hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- WLR_NO_HARDWARE_CURSORS is obsolete. This is the native 0.56 equivalent.
hl.config({
  cursor = {
    no_hardware_cursors = 1,
  },
})
