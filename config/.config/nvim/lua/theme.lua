local M = {}

local registry_file = vim.fn.expand("~/flavors/theme-names.toml")
local fallback = "catppuccin"
local last_mtime = 0

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
    "SignColumn",
    "LineNr",
    "CursorLineNr",
    "Folded",
    "MsgArea",
    "ColorColumn",
    "WinSeparator",
    "TelescopeNormal",
    "TelescopeBorder",
    "TelescopePromptBorder",
    "TelescopeResultsBorder",
    "TelescopePreviewBorder",
    "FloatBorder",
    "Pmenu",
  }

  for _, name in ipairs(groups) do
    pcall(vim.api.nvim_set_hl, 0, name, { bg = "NONE" })
  end
end

local ok_vague, vague = pcall(require, "vague")
if ok_vague then
  vague.setup({
    transparent = true,
  })
end

local function _setup_scheme(scheme)
  local ok_catppuccin, catppuccin = pcall(require, "catppuccin")
  if ok_catppuccin then
    catppuccin.setup({
      transparent_background = true,
      integrations = {
        treesitter = true,
        coc_nvim = true,
        native_lsp = { enabled = true },
      },
    })
  end

  local ok_kanagawa, kanagawa = pcall(require, "kanagawa")
  if ok_kanagawa then
    kanagawa.setup({
      transparent = true,
    })
  end

  local ok_rosepine, rosepine = pcall(require, "rose-pine")
  if ok_rosepine then
    rosepine.setup({
      styles = {
        transparency = true,
      },
    })
  end

  local ok_tokyonight, tokyonight = pcall(require, "tokyonight")
  if ok_tokyonight then
    tokyonight.setup({
      transparent = true,
    })
  end

  if scheme:match("everforest") then
    vim.g.everforest_transparent_background = 2
  end

  if scheme == "gruvbox" then
    vim.g.gruvbox_contrast_dark = "medium"
    vim.g.gruvbox_invert_selection = 0
    vim.g.gruvbox_transparent_bg = 1
  end
end

function M.apply()
  local scheme = _read_app_theme("nvim")

  _setup_scheme(scheme)

  local ok = pcall(vim.cmd.colorscheme, scheme)
  if not ok and scheme ~= fallback then
    pcall(vim.cmd.colorscheme, fallback)
  end

  ForceTransparent()
end

function M.reload()
  M.apply()
end

function M.check()
  local uv = vim.uv or vim.loop
  local stat = uv.fs_stat(registry_file)

  if not stat then
    return
  end

  local mtime = stat.mtime.sec

  if last_mtime > 0 and mtime ~= last_mtime then
    M.reload()
    vim.notify("theme flipped", vim.log.levels.INFO)
  end

  last_mtime = mtime
end

local cycle_themes = {
  "catppuccin",
  "dracula",
  "gruvbox",
  "tokyonight",
  "NeoSolarized",
  "kanagawa-dragon",
  "everforest",
  "rose-pine",
  "vague",
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
  M.check()

  vim.api.nvim_create_augroup("OsyxThemeFlip", { clear = true })

  vim.api.nvim_create_autocmd("FocusGained", {
    group = "OsyxThemeFlip",
    callback = function()
      M.check()
    end,
  })

  vim.api.nvim_create_user_command("OsyxFlip", function()
    M.reload()
  end, { desc = "Reload OSyx app theme registry" })

  vim.api.nvim_create_user_command("OsyxReloadTheme", function()
    M.reload()
  end, { desc = "Reload OSyx app theme registry" })
end

return M