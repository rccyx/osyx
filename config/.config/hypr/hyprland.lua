-- =============================================================================
-- hyprland.lua — Hyprland 0.56 entry point
-- Public modules load first. Personal modules load last.
-- =============================================================================

require("env")
require("monitors")
require("input")
require("appearance")
require("rules")
require("workspaces")

require("_startup")
require("_keybinds")
require("_clipboard")
