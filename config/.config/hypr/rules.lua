-- =============================================================================
-- rules.lua — window rules
-- =============================================================================

hl.window_rule({
  name = "terminal-opacity",
  match = { class = "^(Alacritty|kitty)$" },
  opacity = "0.97",
})

hl.window_rule({
  name = "suppress-maximize-events",
  match = { class = ".*" },
  suppress_event = "maximize",
})

hl.window_rule({
  name = "focus-app-opacity",
  match = { class = "^(firefox|cursor|obsidian|code)$" },
  opacity = "0.9 override 0.9 override",
})
