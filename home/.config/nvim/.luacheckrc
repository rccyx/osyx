stds = {
    nvim = {
        globals = { "vim" },
    },
}

-- The standard environment for Neovim is LuaJIT
std = "luajit+nvim"

-- This prevents "setting/accessing undefined global" errors
new_globals = {
    "ForceTransparent",
    "ReloadTheme",
    "CycleTheme",
}

-- General ignores
ignore = {
    "212", -- Unused argument (common in Neovim callbacks/autocmds)
    "111", -- Setting a global variable (we want this for the _G hooks)
}

-- Avoid linting third-party plugins if they end up in the tree
exclude_files = {
    "plugged",
}
