-- =============================================================================
-- _startup.lua — personal session startup
-- =============================================================================

local variables = __require("_variables")

local function start_on(workspace, command)
  hl.exec_cmd(command, { workspace = tostring(workspace) .. " silent" })
end

hl.on("hyprland.start", function()
  hl.exec_cmd("mkdir -p " .. variables.screenshot_dir)

  start_on(1, "obsidian")
  start_on(2, 'google-chrome --profile-directory="Default" --new-window')

  for _ = 1, 3 do
    start_on(3, variables.term)
  end

  start_on(9, 'brave-browser --profile-directory="Default" --app="https://youtube.com"')

  hl.exec_cmd("hyprpaper")
  hl.exec_cmd("hyprsunset")
  hl.exec_cmd("mako")
  hl.exec_cmd("swww-daemon")
  hl.exec_cmd("waypaper --backend swww --restore")
  hl.exec_cmd("pavucontrol --hide-window --start-hidden")
  hl.exec_cmd("blueman-applet")
end)