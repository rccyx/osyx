let s:config_dir = stdpath('config')
let s:plug_path = s:config_dir . '/autoload/plug.vim'
let s:is_ci = !empty($CI) || !empty($GITHUB_ACTIONS)

" Auto setup all the plugins on first launch (vim-plug bootstrap)
if !s:is_ci && !filereadable(s:plug_path)
  echo "Downloading junegunn/vim-plug to manage plugins..."
  call mkdir(fnamemodify(s:plug_path, ':h'), 'p')
  silent execute '!curl -fsSL https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim -o ' . shellescape(s:plug_path)
  autocmd VimEnter * silent! PlugInstall --sync
endif

call plug#begin(stdpath('config') . '/plugged')

" ----- Theme Plugins -----
Plug 'sainnhe/everforest'
Plug 'morhetz/gruvbox'
Plug 'ficcdaf/ashen.nvim'
Plug 'folke/tokyonight.nvim'
Plug 'EdenEast/nightfox.nvim'
Plug 'vague-theme/vague.nvim'
Plug 'rose-pine/neovim', { 'as': 'rose-pine' }
Plug 'rebelot/kanagawa.nvim'
Plug 'savq/melange-nvim'
Plug 'EdenEast/nightfox.nvim'
Plug 'ramojus/mellifluous.nvim'
Plug 'EdenEast/nightfox.nvim'

" ----- Helper Plugins -----
Plug 'nvim-lua/plenary.nvim'
Plug 'tpope/vim-surround'
Plug 'junegunn/goyo.vim'
Plug 'jreybert/vimagit'
Plug 'vimwiki/vimwiki'
Plug 'tpope/vim-commentary'
Plug 'ryanoasis/vim-devicons'
Plug 'scrooloose/nerdcommenter'
Plug 'sheerun/vim-polyglot'
Plug 'tpope/vim-fugitive'
Plug 'vim-scripts/indentpython.vim'
Plug 'SirVer/ultisnips' | Plug 'honza/vim-snippets'
Plug 'tpope/vim-fireplace', { 'for': 'clojure' }
Plug 'junegunn/fzf'
Plug 'junegunn/fzf.vim'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'nvim-treesitter/nvim-treesitter-textobjects'
Plug 'nvim-telescope/telescope.nvim', { 'tag': 'v0.1.9' }
Plug 'nvim-telescope/telescope-file-browser.nvim'
Plug 'windwp/nvim-autopairs'
Plug 'windwp/nvim-ts-autotag'
Plug 'norcalli/nvim-colorizer.lua'
Plug 'lewis6991/gitsigns.nvim'
Plug 'dinhhuy258/git.nvim'
Plug 'folke/zen-mode.nvim'
Plug 'iamcco/markdown-preview.nvim'

" ----- Language-specific Plugins -----
Plug 'ap/vim-css-color'
Plug 'prisma/vim-prisma'
Plug 'pangloss/vim-javascript'
Plug 'leafgarland/typescript-vim'
Plug 'maxmellon/vim-jsx-pretty'
Plug 'jparise/vim-graphql'
Plug 'rust-lang/rust.vim'
Plug 'cespare/vim-toml', {'branch': 'main'}
Plug 'stephpy/vim-yaml'
Plug 'plasticboy/vim-markdown'

" ----- LSP/Autocomplete -----
Plug 'neoclide/coc.nvim', {'branch': 'release'}

" ----- Added: file ops + sudo + project replace -----
Plug 'tpope/vim-eunuch'
Plug 'lambdalisue/suda.vim'
Plug 'nvim-pack/nvim-spectre'

call plug#end()

" Bridge Treesitter parser names to filetypes used by plugins
lua << EOF
pcall(function()
  vim.treesitter.language.register('tsx', 'typescriptreact')
  vim.treesitter.language.register('javascript', 'javascriptreact')

  local parsers = require("nvim-treesitter.parsers")
  if not parsers.ft_to_lang then
    parsers.ft_to_lang = function(ft)
      return vim.treesitter.language.get_lang(ft) or ft
    end
  end
end)
EOF