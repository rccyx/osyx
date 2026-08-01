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

-- Theme rotation
exec("ALT + R", [[zsh -ic 'themes rotate']])

-- Screenshots
exec("XF86Launch2", variables.home .. "/.local/bin/shot-full")
exec("Print", variables.home .. "/.local/bin/shot-mac")
exec(mod .. " + SHIFT + S", [[grim -g "$(slurp)" - | swappy -f -]])

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
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + P", hl.dsp.window.pseudo({ action = "toggle" }))
hl.bind(mod .. " + S", hl.dsp.layout("togglesplit"))

-- Focus and movement
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

-- Relative workspace navigation and window cycling
hl.bind("CTRL + ALT + left", hl.dsp.focus({ workspace = "r-1" }))
hl.bind("CTRL + ALT + right", hl.dsp.focus({ workspace = "r+1" }))
hl.bind("ALT + TAB", hl.dsp.window.cycle_next())
hl.bind("ALT + SHIFT + TAB", hl.dsp.window.cycle_next({ next = false }))

-- Workspace selection: number row
for workspace = 1, 10 do
  local key = workspace % 10
  hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
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
  hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = workspace }))
end

-- Move windows by physical top-row keycode, independent of keyboard layout
for workspace = 1, 10 do
  local keycode = workspace + 9
  hl.bind(mod .. " + SHIFT + code:" .. keycode, hl.dsp.window.move({ workspace = workspace }))
end

-- Audio and brightness. Locked binds still work while the lock screen is active.
exec("XF86AudioRaiseVolume", "pamixer -i 5", { locked = true, repeating = true })
exec("XF86AudioLowerVolume", "pamixer -d 5", { locked = true, repeating = true })
exec("XF86AudioMute", "pamixer -t", { locked = true })
exec("XF86AudioMicMute", "pamixer --default-source -t", { locked = true })
exec("XF86MonBrightnessUp", "brightnessctl set +5%", { locked = true, repeating = true })
exec("XF86MonBrightnessDown", "brightnessctl set 5%-", { locked = true, repeating = true })

-- Mouse window manipulation
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })