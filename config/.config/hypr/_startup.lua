-- =============================================================================
-- _startup.lua — personal session startup
-- =============================================================================

local variables = __require("_variables")

local function start_on(workspace, command)
  hl.exec_cmd(command, {
    workspace = tostring(workspace) .. " silent",
  })
end

local chrome_rule = hl.window_rule({
  name = "startup-chrome-workspace",
  match = {
    class = "^(google-chrome|Google-chrome|google-chrome-stable|Google-chrome-stable)$",
  },
  workspace = "2 silent",
})

local brave_rule = hl.window_rule({
  name = "startup-brave-workspace",
  match = {
    class = "^(brave-browser|Brave-browser|brave-browser-beta|Brave-browser-beta|brave-browser-nightly|Brave-browser-nightly)$",
  },
  workspace = "9 silent",
})

-- these rules must only affect windows launched during initial session startup.
-- keeping them disabled also prevents a normal config reload from changing where
-- future browser windows open.
chrome_rule:set_enabled(false)
brave_rule:set_enabled(false)

local function disable_consumed_startup_rule(window)
  if window == nil then
    return
  end

  local class = string.lower(
    window.class
      or window.initial_class
      or ""
  )

  if chrome_rule:is_enabled()
      and (
        class == "google-chrome"
        or class == "google-chrome-stable"
      ) then
    chrome_rule:set_enabled(false)
    return
  end

  if brave_rule:is_enabled()
      and (
        class == "brave-browser"
        or class == "brave-browser-beta"
        or class == "brave-browser-nightly"
      ) then
    brave_rule:set_enabled(false)
  end
end

-- window.open runs after static window rules have already been applied.
hl.on("window.open", disable_consumed_startup_rule)

hl.on("hyprland.start", function()
  hl.exec_cmd("mkdir -p " .. variables.screenshot_dir)

  -- these apps retain their launched PID, so exec rules work normally.
  start_on(1, "obsidian")

  for _ = 1, 3 do
    start_on(3, variables.term)
  end

  -- chromium browsers don't reliably retain the PID launched by Hyprland.
  -- enable the one-shot class rules before starting them.
  chrome_rule:set_enabled(true)
  brave_rule:set_enabled(true)

  hl.exec_cmd(
    'google-chrome --profile-directory="Default" --new-window'
  )

  hl.exec_cmd(
    'brave-browser --profile-directory="Default" --app="https://youtube.com"'
  )

  hl.exec_cmd("hyprpaper")
  hl.exec_cmd("hyprsunset")
  hl.exec_cmd("mako")
  hl.exec_cmd("swww-daemon")
  hl.exec_cmd("waypaper --backend swww --restore")
  hl.exec_cmd("pavucontrol --hide-window --start-hidden")
  hl.exec_cmd("blueman-applet")
end)