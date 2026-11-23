-- Apps to open when the session starts.
local variables = __require("_variables")

-- silent keeps the current workspace on screen.
local function start_on(workspace, command)
    hl.exec_cmd(command, {
        workspace = tostring(workspace) .. " silent",
    })
end

-- Chromium forks, so launch-PID rules can miss its windows. Use the window class.
local chrome_rule = hl.window_rule({
    name = "startup-chrome-workspace",
    match = { class = "^(google-chrome|Google-chrome|google-chrome-stable|Google-chrome-stable)$" },
    workspace = "2 silent",
})

local brave_rule = hl.window_rule({
    name = "startup-brave-workspace",
    match = { class = "^(brave-browser|Brave-browser|brave-browser-beta|Brave-browser-beta|brave-browser-nightly|Brave-browser-nightly)$" },
    workspace = "9 silent",
})

-- Keep browser placement off on reload.
chrome_rule:set_enabled(false)
brave_rule:set_enabled(false)

local function disable_consumed_startup_rule(window)
    if window == nil then
        return
    end

    local class = string.lower(window.class or window.initial_class or "")

    if chrome_rule:is_enabled() and (class == "google-chrome" or class == "google-chrome-stable") then
        chrome_rule:set_enabled(false)
        return
    end

    if brave_rule:is_enabled() and (
        class == "brave-browser" or class == "brave-browser-beta" or class == "brave-browser-nightly"
    ) then
        brave_rule:set_enabled(false)
    end
end

-- Placement has already happened here. Turn the rule off for later windows.
hl.on("window.open", disable_consumed_startup_rule)

-- Run at session start. Reloading does not run this block.
hl.on("hyprland.start", function()
    hl.exec_cmd("mkdir -p " .. variables.screenshot_dir)

    -- Apps with a target workspace
    start_on(1, "obsidian")

    for _ = 1, 3 do
        start_on(3, variables.term)
    end

    -- Each browser rule turns off after its first matching window opens.
    chrome_rule:set_enabled(true)
    brave_rule:set_enabled(true)

    hl.exec_cmd('google-chrome --profile-directory="Default" --new-window')

    hl.exec_cmd('brave-browser --profile-directory="Default" --app="https://youtube.com"')

    -- Background programs. These launches do not wait for each other.
    hl.exec_cmd("swww-daemon") -- restores the previous wallpaper from its cache
    hl.exec_cmd("hyprsunset") -- nigh mode
    hl.exec_cmd("mako") -- notficiations
    hl.exec_cmd("pavucontrol --hide-window --start-hidden") --audio 
    hl.exec_cmd("blueman-applet") -- blutooth
end)
