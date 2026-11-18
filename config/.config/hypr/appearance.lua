local theme = __require("theme")

hl.config({
    -- Layout and borders
    general = {
        gaps_in = 6,
        gaps_out = 18,
        border_size = 2,
        col = {
            inactive_border = theme.inactive_border,
            active_border = theme.active_border,
        },
        resize_on_border = true,
        layout = "dwindle",
        allow_tearing = false,
    },

    -- Window effects
    decoration = {
        rounding = 12,
        active_opacity = 1.0,
        inactive_opacity = 0.90,

        blur = {
            enabled = true,
            size = 6,
            passes = 2,
        },
    },

    animations = { enabled = true },

    dwindle = { preserve_split = true },
})

-- Animation curve
hl.curve("ease", {
    type = "bezier",
    points = {
        { 0.2, 0.9 },
        { 0.2, 1.0 },
    },
})

hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "ease", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "ease" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "ease" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "ease", style = "slide" })
