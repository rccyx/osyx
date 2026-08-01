-- =============================================================================
-- variables.lua — shared values
-- Pure Lua module. Import with __require("variables").
-- =============================================================================

local home = os.getenv("HOME")
local config_home = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")

return {
  home = home,
  config_home = config_home,
  mod = "SUPER",
  term = "kitty",
  menu = "wofi --show drun",
  screenshot_dir = home .. "/Pictures/Screenshots",
}
