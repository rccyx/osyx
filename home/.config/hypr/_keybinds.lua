-- Keybinds
local variables = __require("_variables")
local mod = variables.mod

-- Theme rotation
hl.bind("ALT + R", hl.dsp.exec_cmd([[zsh -ic 'themes rotate']]))

-- Screenshots. dont_inhibit bypasses inhibitors. transparent keeps the active submap.
local shot_full = variables.home .. "/.local/bin/shot-full"
local shot_mac = variables.home .. "/.local/bin/shot-mac"

-- Full-screen capture
hl.bind("F9", hl.dsp.exec_cmd(shot_full), { dont_inhibit = true, transparent = true })
hl.bind("XF86Launch2", hl.dsp.exec_cmd(shot_full), { dont_inhibit = true, transparent = true })

-- Region capture
hl.bind("F10", hl.dsp.exec_cmd(shot_mac), { dont_inhibit = true, transparent = true })
hl.bind("Print", hl.dsp.exec_cmd(shot_mac), { dont_inhibit = true, transparent = true })
hl.bind("Sys_Req", hl.dsp.exec_cmd(shot_mac), { dont_inhibit = true, transparent = true })

-- Region capture with annotation
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd([[grim -g "$(slurp)" - | swappy -f -]]), {
    dont_inhibit = true,
    transparent = true,
})

-- Apps
hl.bind("SUPER + X", hl.dsp.exec_cmd("clipyx"))
hl.bind("ALT + M", hl.dsp.exec_cmd("ctrlyx"))
hl.bind("ALT + P", hl.dsp.exec_cmd("powyx"))
hl.bind("ALT + O", hl.dsp.exec_cmd("obsidian"))
hl.bind("ALT + S", hl.dsp.exec_cmd("spotify"))
hl.bind("ALT + E", hl.dsp.exec_cmd("code"))
hl.bind("ALT + F", hl.dsp.exec_cmd("nautilus"))
hl.bind("ALT + G", hl.dsp.exec_cmd("google-chrome"))
hl.bind("ALT + L", hl.dsp.exec_cmd("hyprlock"))

hl.bind("ALT + C", hl.dsp.exec_cmd("Cap"))
hl.bind("ALT + V", hl.dsp.exec_cmd(variables.home .. "/.local/bin/vocaster"))
hl.bind("ALT + W", hl.dsp.exec_cmd(variables.home .. "/.local/bin/asryx"))

-- Web apps
hl.bind("ALT + SHIFT + C", hl.dsp.exec_cmd(variables.webapp .. "https://calendar.google.com"))
hl.bind("ALT + SHIFT + Y", hl.dsp.exec_cmd(variables.webapp .. "https://youtube.com"))
hl.bind("ALT + SHIFT + S", hl.dsp.exec_cmd(variables.webapp .. "https://soundcloud.com"))

-- Launchers and terminals
hl.bind("ALT + Return", hl.dsp.exec_cmd(variables.term))
hl.bind(mod .. " + Space", hl.dsp.exec_cmd(variables.menu))
hl.bind("ALT + K", hl.dsp.exec_cmd(variables.term))
hl.bind("ALT + Q", hl.dsp.exec_cmd(variables.term))

-- Window state
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind("ALT + F4", hl.dsp.window.close())

hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))

hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))

hl.bind(mod .. " + P", hl.dsp.window.pseudo({ action = "toggle" }))

hl.bind(mod .. " + S", hl.dsp.layout("togglesplit"))

-- Arrows focus windows. Shift + arrows moves them.
local directions = {
    left = "l",
    right = "r",
    up = "u",
    down = "d",
}

for key, direction in pairs(directions) do
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = direction }))

    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = direction }))
end

-- Previous and next workspace
hl.bind("CTRL + ALT + left", hl.dsp.focus({ workspace = "r-1" }))

hl.bind("CTRL + ALT + right", hl.dsp.focus({ workspace = "r+1" }))

-- Window cycling
hl.bind("ALT + TAB", hl.dsp.window.cycle_next())

hl.bind("ALT + SHIFT + TAB", hl.dsp.window.cycle_next({ next = false }))

-- Workspace numbers. Workspace 10 uses 0.
for workspace = 1, 10 do
    local key = workspace % 10

    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
end

-- AZERTY number-row symbols, without Shift.
local azerty = {
    "ampersand",
    "eacute",
    "quotedbl",
    "apostrophe",
    "parenleft",
    "minus",
    "egrave",
    "underscore",
    "ccedilla",
    "agrave",
}

for workspace, key in ipairs(azerty) do
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
end

-- Use physical keys for Shift + number-row moves because AZERTY changes the symbols.
for workspace = 1, 10 do
    local keycode = workspace + 9

    hl.bind(mod .. " + SHIFT + code:" .. keycode, hl.dsp.window.move({ workspace = workspace }))
end

-- locked allows these keys on the lock screen.
-- Repeat volume and brightness while held. Mute only toggles once.
hl.bind("F1", hl.dsp.exec_cmd("pamixer -t"), { locked = true, repeating = false })
hl.bind("F2", hl.dsp.exec_cmd("pamixer -d 5"), { locked = true, repeating = true })
hl.bind("F3", hl.dsp.exec_cmd("pamixer -i 5"), { locked = true, repeating = true })
hl.bind("F6", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
hl.bind("F7", hl.dsp.exec_cmd("brightnessctl set +5%"), { locked = true, repeating = true })

-- Same controls when Fn-lock or another keyboard sends media keys.
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("pamixer -t"), { locked = true, repeating = false })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pamixer -d 5"), { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pamixer -i 5"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("pamixer --default-source -t"), { locked = true, repeating = false })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set +5%"), { locked = true, repeating = true })

-- Modifier + left drag moves. Modifier + right drag resizes.
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })

hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
