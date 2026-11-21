-- QML animates these overlays. no_anim stops Hyprland from sliding them too.
hl.window_rule({
    name = "powyx-overlay",
    match = { initial_title = "^powyx$" },
    float = true,
    fullscreen = true,
    no_anim = true,
})

hl.window_rule({
    name = "ctrlyx-overlay",
    match = { initial_title = "^ctrlyx$" },
    float = true,
    fullscreen = true,
    no_anim = true,
})


hl.window_rule({
    name = "clipyx-overlay",
    match = { initial_title = "^clipyx$" },
    float = true,
    fullscreen = true,
    no_anim = true,
})

-- Terminal opacity.
hl.window_rule({
    name = "terminal-opacity",
    match = { class = "^(Alacritty|kitty)$" },
    opacity = "0.97",
})

-- Ignore app maximize requests.
hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- Fixed app opacity
hl.window_rule({
    name = "focus-app-opacity",
    match = { class = "^(firefox|cursor|obsidian|code)$" },
    opacity = "0.9 override 0.9 override", -- Override active and inactive opacity.
})
