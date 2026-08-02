-- =============================================================================
-- rules.lua — window rules
-- =============================================================================

-- this is soo important to get that smooth drop with QML, otherwise the normal hypr animations interfere with it 
-- and slides it vertically like any other window
hl.window_rule({
  name = "powyx-no-window-animation",
  match = {
    initial_title = "^powyx$",
  },
  no_anim = true,
})

hl.window_rule({
  name = "ctrlyx-no-window-animation",
  match = {
    initial_title = "^ctrlyx$",
  },
  no_anim = true,
})
--

hl.window_rule({
  name = "terminal-opacity",
  match = {
    class = "^(Alacritty|kitty)$",
  },
  opacity = "0.97",
})

hl.window_rule({
  name = "suppress-maximize-events",
  match = {
    class = ".*",
  },
  suppress_event = "maximize",
})

hl.window_rule({
  name = "focus-app-opacity",
  match = {
    class = "^(firefox|cursor|obsidian|code)$",
  },
  opacity = "0.9 override 0.9 override",
})