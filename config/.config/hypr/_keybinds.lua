local variables = __require("_variables")
local mod = variables.mod

local function exec(keys, command, options)
    if options then
        hl.bind(keys, hl.dsp.exec_cmd(command), options)
    else
        hl.bind(keys, hl.dsp.exec_cmd(command))
    end
end

local function webapp(url)
    return variables.webapp .. url
end

local function hardware_bind(key, command, repeating)
    exec(key, command, {
        locked = true,
        repeating = repeating,
    })
end

local function screenshot_bind(key, command)
    exec(key, command, {
        dont_inhibit = true,
        transparent = true,
    })
end

-- Theme rotation
exec("ALT + R", [[zsh -ic 'themes rotate']])

-- Screenshots
local shot_full = variables.home .. "/.local/bin/shot-full"
local shot_mac = variables.home .. "/.local/bin/shot-mac"

-- F9: instant full-screen capture
screenshot_bind("F9", shot_full)
screenshot_bind("XF86Launch2", shot_full)

-- F10 and Print: Mac-style region capture
screenshot_bind("F10", shot_mac)
screenshot_bind("Print", shot_mac)
screenshot_bind("Sys_Req", shot_mac)

-- Region capture with annotation
screenshot_bind(
    mod .. " + SHIFT + S",
    [[grim -g "$(slurp)" - | swappy -f -]]
)

-- Apps
exec("ALT + O", "obsidian")
exec("ALT + S", "spotify")
exec("ALT + E", "code")
exec("ALT + F", "nautilus")
exec("ALT + G", "google-chrome")
exec("ALT + L", "hyprlock")
exec("ALT + M", "ctrlyx")
exec("ALT + P", "powyx")
exec("ALT + V", variables.home .. "/.local/bin/vocaster")
exec("ALT + W", variables.home .. "/.local/bin/asryx")

-- Web apps
exec("ALT + SHIFT + C", webapp("https://calendar.google.com"))
exec("ALT + SHIFT + Y", webapp("https://youtube.com"))
exec("ALT + SHIFT + S", webapp("https://soundcloud.com"))

-- Launchers and terminals
exec("ALT + Return", variables.term)
exec(mod .. " + Space", variables.menu)
exec("ALT + K", variables.term)
exec("ALT + Q", variables.term)

-- Window state
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind("ALT + F4", hl.dsp.window.close())

hl.bind(
    mod .. " + F",
    hl.dsp.window.fullscreen({
        mode = "maximized",
        action = "toggle",
    })
)

hl.bind(
    mod .. " + V",
    hl.dsp.window.float({
        action = "toggle",
    })
)

hl.bind(
    mod .. " + P",
    hl.dsp.window.pseudo({
        action = "toggle",
    })
)

hl.bind(mod .. " + S", hl.dsp.layout("togglesplit"))

-- Focus and movement
local directions = {
    left = "l",
    right = "r",
    up = "u",
    down = "d",
}

for key, direction in pairs(directions) do
    hl.bind(
        mod .. " + " .. key,
        hl.dsp.focus({
            direction = direction,
        })
    )

    hl.bind(
        mod .. " + SHIFT + " .. key,
        hl.dsp.window.move({
            direction = direction,
        })
    )
end

-- Relative workspace navigation
hl.bind(
    "CTRL + ALT + left",
    hl.dsp.focus({
        workspace = "r-1",
    })
)

hl.bind(
    "CTRL + ALT + right",
    hl.dsp.focus({
        workspace = "r+1",
    })
)

-- Window cycling
hl.bind("ALT + TAB", hl.dsp.window.cycle_next())

hl.bind(
    "ALT + SHIFT + TAB",
    hl.dsp.window.cycle_next({
        next = false,
    })
)

-- Workspace selection: number row
for workspace = 1, 10 do
    local key = workspace % 10

    hl.bind(
        mod .. " + " .. key,
        hl.dsp.focus({
            workspace = workspace,
        })
    )
end

-- Workspace selection: French AZERTY symbols
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
    hl.bind(
        mod .. " + " .. key,
        hl.dsp.focus({
            workspace = workspace,
        })
    )
end

-- Move windows by physical top-row keycode, independent of keyboard layout
for workspace = 1, 10 do
    local keycode = workspace + 9

    hl.bind(
        mod .. " + SHIFT + code:" .. keycode,
        hl.dsp.window.move({
            workspace = workspace,
        })
    )
end

-- Laptop function row
hardware_bind("F1", "pamixer -t", false)
hardware_bind("F2", "pamixer -d 5", true)
hardware_bind("F3", "pamixer -i 5", true)
hardware_bind("F6", "brightnessctl set 5%-", true)
hardware_bind("F7", "brightnessctl set +5%", true)

-- Media-key aliases for Fn-lock and keyboards that emit XF86 keysyms
hardware_bind("XF86AudioMute", "pamixer -t", false)
hardware_bind("XF86AudioLowerVolume", "pamixer -d 5", true)
hardware_bind("XF86AudioRaiseVolume", "pamixer -i 5", true)
hardware_bind(
    "XF86AudioMicMute",
    "pamixer --default-source -t",
    false
)
hardware_bind(
    "XF86MonBrightnessDown",
    "brightnessctl set 5%-",
    true
)
hardware_bind(
    "XF86MonBrightnessUp",
    "brightnessctl set +5%",
    true
)

-- Mouse window manipulation
hl.bind(
    mod .. " + mouse:272",
    hl.dsp.window.drag(),
    {
        mouse = true,
    }
)

hl.bind(
    mod .. " + mouse:273",
    hl.dsp.window.resize(),
    {
        mouse = true,
    }
)