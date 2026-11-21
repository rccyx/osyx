set shell=/usr/bin/zsh
set shellredir=>%s\ 2>&1
set encoding=utf-8
set number
set relativenumber
set autoindent
set shiftwidth=4
set smarttab
set title
set background=dark

if exists("&guioptions")
  set guioptions+=a
endif

set mouse=a
set nohlsearch
set clipboard+=unnamedplus
set noshowmode
set noruler
set laststatus=0
set noshowcmd
set showtabline=0
filetype plugin indent on
syntax on

if executable('/usr/bin/python3')
  let g:python3_host_prog = '/usr/bin/python3'
endif

set termguicolors

" Bridge Treesitter parser names to filetypes used by plugins
lua << EOF
pcall(function()
  vim.treesitter.language.register('tsx', 'typescriptreact')
  vim.treesitter.language.register('javascript', 'javascriptreact')
end)
EOF

" Auto-format
augroup CoCAutoFormat
  autocmd!
  autocmd BufWritePre *.ts,*.tsx,*.js,*.jsx,*.json,*.css,*.md,*.py,*.rs,*.go,*.prisma,*.c,*.cc,*.cpp,*.cxx,*.h,*.hh,*.hpp,*.hxx silent! call CocActionAsync('format')
augroup END

" Python venv activator
function! s:project_root() abort
  let l:gitdir = finddir('.git', expand('%:p:h').';')
  return empty(l:gitdir) ? getcwd() : fnamemodify(l:gitdir, ':h')
endfunction

function! s:activate_venv() abort
  let l:root = s:project_root()
  for l:name in ['.venv', 'venv']
    let l:py = l:root.'/'.l:name.'/bin/python'
    if filereadable(l:py)
      let g:python3_host_prog = l:py
      let $VIRTUAL_ENV = l:root.'/'.l:name
      let $PATH = l:root.'/'.l:name.'/bin:'.$PATH
      break
    endif
  endfor
endfunction
autocmd VimEnter,BufEnter *.py call s:activate_venv()