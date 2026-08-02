local M = {}

local uv = vim.uv or vim.loop

local registry_file = vim.fn.expand("~/flavors/theme-names.toml")
local registry_dir = vim.fn.fnamemodify(registry_file, ":h")
local registry_name = vim.fn.fnamemodify(registry_file, ":t")
local fallback = "vague"

local watcher = nil
local reload_timer = nil

local function _trim(value)
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function _escape_pattern(value)
  return value:gsub("([^%w])", "%%%1")
end

local function _read_app_theme(app)
  local ok, lines = pcall(vim.fn.readfile, registry_file)

  if not ok or #lines == 0 then
    return fallback
  end

  local key = _escape_pattern(app)
  local in_apps = false

  for _, raw in ipairs(lines) do
    local line = _trim(raw)

    if line ~= "" and not line:match("^#") then
      local section = line:match("^%[([^%]]+)%]$")

      if section then
        in_apps = section == "apps"
      elseif in_apps then
        local quoted = line:match('^"' .. key .. '"%s*=%s*"([^"]+)"%s*$')
        local bare = line:match("^" .. key .. '%s*=%s*"([^"]+)"%s*$')
        local value = quoted or bare

        if value and _trim(value) ~= "" then
          return _trim(value)
        end
      end
    end
  end

  return fallback
end

_G.ForceTransparent = function()
  local groups = {
    "Normal",
    "NormalFloat",
    "NormalNC",
    "SignColumn",
    "LineNr",
    "CursorLineNr",
    "FoldColumn",
    "Folded",
    "EndOfBuffer",
    "MsgArea",
    "ColorColumn",
    "WinSeparator",
    "TelescopeNormal",
    "TelescopeBorder",
    "TelescopePromptNormal",
    "TelescopePromptBorder",
    "TelescopeResultsNormal",
    "TelescopeResultsBorder",
    "TelescopePreviewNormal",
    "TelescopePreviewBorder",
    "FloatBorder",
    "Pmenu",
  }

  for _, name in ipairs(groups) do
    pcall(vim.api.nvim_set_hl, 0, name, { bg = "NONE" })
  end
end

local nightfox_schemes = {
  nightfox = true,
  dayfox = true,
  dawnfox = true,
  duskfox = true,
  nordfox = true,
  terafox = true,
  carbonfox = true,
}

local function _setup_scheme(scheme)
  if scheme == "everforest" then
    vim.g.everforest_transparent_background = 2
    return
  end

  if scheme == "gruvbox" then
    vim.g.gruvbox_contrast_dark = "medium"
    vim.g.gruvbox_invert_selection = 0
    return
  end

  if nightfox_schemes[scheme] then
    local ok, nightfox = pcall(require, "nightfox")
    if ok then
      nightfox.setup({
        options = {
          transparent = true,
          terminal_colors = true,
          dim_inactive = false,
          styles = {
            comments = "NONE",
            conditionals = "NONE",
            constants = "NONE",
            functions = "NONE",
            keywords = "NONE",
            numbers = "NONE",
            operators = "NONE",
            strings = "NONE",
            types = "NONE",
            variables = "NONE",
          },
        },
      })
    end
    return
  end

  if scheme == "ashen" then
    local ok, ashen = pcall(require, "ashen")

    if ok then
      ashen.setup({
        transparent = true,
      })
    end

    return
  end

  if scheme == "mellifluous" then
    local ok, mellifluous = pcall(require, "mellifluous")

    if ok then
      mellifluous.setup({
        colorset = "alduin",
        transparent_background = {
          enabled = true,
          floating_windows = true,
          telescope = true,
          file_tree = true,
          cursor_line = true,
          status_line = false,
        },
      })
    end
    return
  end

  if scheme == "tokyonight" or scheme:match("^tokyonight%-") then
    local ok, tokyonight = pcall(require, "tokyonight")

    if ok then
      tokyonight.setup({
        style = "night",
        transparent = true,
        styles = {
          sidebars = "transparent",
          floats = "transparent",
        },
      })
    end

    return
  end

  if scheme == "terafox" then
    local ok, nightfox = pcall(require, "nightfox")

    if ok then
      nightfox.setup({
        options = {
          transparent = true,
        },
      })
    end

    return
  end

  if scheme == "vague" then
    local ok, vague = pcall(require, "vague")

    if ok then
      vague.setup({
        transparent = true,
      })
    end

    return
  end

  if scheme == "rose-pine" or scheme:match("^rose%-pine%-") then
    local ok, rosepine = pcall(require, "rose-pine")

    if ok then
      rosepine.setup({
        variant = "moon",
        dark_variant = "moon",
        styles = {
          transparency = true,
        },
      })
    end

    return
  end

  if scheme == "kanagawa" or scheme:match("^kanagawa%-") then
    local ok, kanagawa = pcall(require, "kanagawa")

    if ok then
      kanagawa.setup({
        transparent = true,
      })
    end
  end
end

function M.apply()
  local scheme = _read_app_theme("nvim")

  _setup_scheme(scheme)

  local ok = pcall(vim.cmd.colorscheme, scheme)

  if not ok and scheme ~= fallback then
    _setup_scheme(fallback)
    pcall(vim.cmd.colorscheme, fallback)
  end

  ForceTransparent()
end

function M.reload()
  M.apply()
end

local function _close_handle(handle)
  if not handle then
    return
  end

  pcall(function()
    handle:stop()
  end)

  if not handle:is_closing() then
    handle:close()
  end
end

local function _stop_watcher()
  _close_handle(watcher)
  _close_handle(reload_timer)

  watcher = nil
  reload_timer = nil
end

local function _queue_reload()
  if not reload_timer then
    return
  end

  reload_timer:stop()
  reload_timer:start(50, 0, vim.schedule_wrap(function()
    M.reload()
  end))
end

local function _watch_registry()
  _stop_watcher()

  watcher = uv.new_fs_event()
  reload_timer = uv.new_timer()

  if not watcher or not reload_timer then
    _stop_watcher()
    vim.notify("failed to create OSyx theme watcher", vim.log.levels.ERROR)
    return
  end

  watcher:unref()
  reload_timer:unref()

  local ok, error_message = watcher:start(registry_dir, {}, function(error, filename)
    if error then
      vim.schedule(function()
        vim.notify("OSyx theme watcher failed: " .. error, vim.log.levels.ERROR)
      end)
      return
    end

    local changed_name = filename and filename:match("([^/]+)$") or nil

    if changed_name == nil or changed_name == registry_name then
      _queue_reload()
    end
  end)

  if not ok then
    _stop_watcher()
    vim.notify("failed to watch OSyx theme registry: " .. tostring(error_message), vim.log.levels.ERROR)
  end
end

local cycle_themes = {
  "everforest",
  "gruvbox",
  "ashen",
  "tokyonight",
  "terafox",
  "nightfox",
  "duskfox",
  "vague",
  "rose-pine",
  "kanagawa-dragon",
  "melange",
}

local cycle_index = 1

_G.CycleTheme = function()
  cycle_index = cycle_index % #cycle_themes + 1

  local scheme = cycle_themes[cycle_index]

  _setup_scheme(scheme)

  local ok = pcall(vim.cmd.colorscheme, scheme)

  if ok then
    ForceTransparent()
    print("theme: " .. scheme)
  else
    print("theme failed: " .. scheme)
  end
end

_G.ReloadTheme = function()
  M.reload()
end

function M.setup()
  M.apply()

  local group = vim.api.nvim_create_augroup("OsyxThemeFlip", { clear = true })

  vim.api.nvim_create_user_command("OsyxFlip", function()
    M.reload()
  end, { desc = "Reload OSyx app theme registry" })

  vim.api.nvim_create_user_command("OsyxReloadTheme", function()
    M.reload()
  end, { desc = "Reload OSyx app theme registry" })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    callback = _stop_watcher,
  })

  _watch_registry()
end

return M
