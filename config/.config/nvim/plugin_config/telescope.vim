lua << EOF
local ok_telescope, telescope = pcall(require, "telescope")
if not ok_telescope then
  return
end

local actions = require("telescope.actions")
local fb_actions = require("telescope._extensions.file_browser.actions")

telescope.setup({
  defaults = {
    vimgrep_arguments = {
      "rg",
      "--hidden",
      "--glob",
      "!.git/*",
      "--no-heading",
      "--with-filename",
      "--line-number",
      "--column",
      "--smart-case",
    },
    sorting_strategy = "ascending",
    layout_config = {
      prompt_position = "top",
    },
    mappings = {
      i = {
        ["<C-q>"] = actions.send_selected_to_qflist + actions.open_qflist,
      },
      n = {
        ["q"] = actions.close,
      },
    },
  },
  pickers = {
    live_grep = {
      only_sort_text = true,
    },
    grep_string = {
      only_sort_text = true,
    },
  },
  extensions = {
    file_browser = {
      hijack_netrw = true,
      grouped = true,
      hidden = true,
      respect_gitignore = false,

      -- Open as a normal file browser instead of a search prompt.
      initial_mode = "normal",

      mappings = {
        n = {
          -- Navigation
          ["<CR>"] = actions.select_default,
          ["<Down>"] = actions.move_selection_next,
          ["<Up>"] = actions.move_selection_previous,
          ["<BS>"] = fb_actions.goto_parent_dir,
          ["h"] = fb_actions.goto_parent_dir,
          ["l"] = actions.select_default,
          ["q"] = actions.close,

          -- File operations
          ["c"] = fb_actions.create,
          ["r"] = fb_actions.rename,
          ["d"] = fb_actions.remove,
          ["m"] = fb_actions.move,
          ["y"] = fb_actions.copy,

          -- Hidden files
          ["."] = fb_actions.toggle_hidden,
        },
        i = {
          -- Never map <C-m>: Neovim treats it as Enter.
          ["<CR>"] = actions.select_default,
          ["<Down>"] = actions.move_selection_next,
          ["<Up>"] = actions.move_selection_previous,
          ["<BS>"] = fb_actions.backspace,
        },
      },
    },
  },
})

telescope.load_extension("file_browser")
EOF

nnoremap <leader>f :Telescope file_browser path=%:p:h<CR>
nnoremap <silent> <leader>r <cmd>Telescope live_grep<CR>
nnoremap <silent> <leader>R <cmd>Telescope grep_string<CR>