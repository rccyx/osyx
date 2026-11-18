-- Entry point. Runs at startup and on reload.
-- require loads config files. __require gets tables such as variables and theme.

-- Desktop settings
require("env")
require("monitors")
require("input")
require("appearance")
require("window_rules")
require("workspaces")

-- Personal config loads last so its settings take priority.
require("_startup")
require("_keybinds")
