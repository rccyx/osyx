-- =============================================================================
-- theme.lua — Lua-native theme values
--
-- The fallback values below are canonical. For compatibility with the existing
-- Flavors generator, a generated theme.conf can override these two values when
-- present. Hyprland itself still receives native Lua values only.
-- =============================================================================

local variables = __require("variables")

local theme = {
  active_border = "rgba(018a83ff)",
  inactive_border = "rgba(002a24ff)",
}

local legacy_path = variables.config_home .. "/hypr/theme.conf"
local file = io.open(legacy_path, "r")

if file then
  for line in file:lines() do
    local key, value = line:match("^%s*%$([%w_]+)%s*=%s*(.-)%s*$")
    if key == "active_border" or key == "inactive_border" then
      theme[key] = value
    end
  end
  file:close()
end

return theme
