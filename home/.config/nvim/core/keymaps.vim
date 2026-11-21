let mapleader = ","
nnoremap c "_c

" Custom mapping for quick text placeholder navigation
nnoremap ,, :keepp /<++><CR>ca<
inoremap ,, <esc>:keepp /<++><CR>ca<

silent! nunmap <leader>bl
nnoremap <silent> <leader>bl <cmd>Telescope buffers sort_lastused=true ignore_current_buffer=true<cr>

let g:ash_showtabline = 0
function! ToggleBufferTabs()
  if g:ash_showtabline == 2 | let g:ash_showtabline = 0 | else | let g:ash_showtabline = 2 | endif
  execute 'set showtabline=' . g:ash_showtabline
endfunction
nnoremap <silent> <leader>bt :call ToggleBufferTabs()<CR>

" Undo / Save / Quit overrides
silent! nunmap <C-r> | silent! vunmap <C-r> | silent! iunmap <C-r>
silent! nunmap <C-u> | silent! vunmap <C-u> | silent! iunmap <C-u>
silent! nunmap <C-z> | silent! vunmap <C-z> | silent! iunmap <C-z>
silent! nunmap <C-s> | silent! vunmap <C-s> | silent! iunmap <C-s>
silent! nunmap <C-q> | silent! vunmap <C-q> | silent! iunmap <C-q>
silent! nunmap <C-a> | silent! vunmap <C-a> | silent! iunmap <C-a>

nnoremap <C-z> u
inoremap <C-z> <C-o>u
vnoremap <C-z> <Esc>u

nnoremap <C-S-z> <C-r>
inoremap <C-S-z> <C-o><C-r>
vnoremap <C-S-z> <Esc><C-r>
nnoremap <C-y> <C-r>
inoremap <C-y> <C-o><C-r>
vnoremap <C-y> <Esc><C-r>

nnoremap <C-s> :update<CR>
inoremap <C-s> <C-o>:update<CR>
vnoremap <C-s> <Esc>:update<CR>gv

nnoremap <C-p> :stop<CR>
inoremap <C-p> <C-o>:stop<CR>
vnoremap <C-p> <Esc>:stop<CR>

nnoremap <C-q> :q!<CR>
inoremap <C-q> <C-o>:q!<CR>
vnoremap <C-q> <Esc>:q!<CR>

function! CycleBufNext()
  if exists(':BufferLineCycleNext') && &showtabline > 0 | execute 'BufferLineCycleNext' | else | bnext | endif
endfunction
function! CycleBufPrev()
  if exists(':BufferLineCyclePrev') && &showtabline > 0 | execute 'BufferLineCyclePrev' | else | bprevious | endif
endfunction
nnoremap <silent> <Tab>   :call CycleBufNext()<CR>
nnoremap <silent> <S-Tab> :call CycleBufPrev()<CR>

inoremap <silent> <C-x> <C-o>:bd<CR>
vnoremap <silent> <C-x> <Esc>:bd<CR>
nnoremap <silent> <C-x> :bd<CR>

" File Path Helpers
nnoremap <leader>fa :echo expand('%:p')<CR>
nnoremap <leader>ft :echo expand('%:t')<CR>
nnoremap <leader>fr :echo fnamemodify(expand('%'), ':.')<CR>
nnoremap <leader>fy :let @+ = fnamemodify(expand('%'), ':.') \| echo 'yanked relative file path'<CR>
nnoremap <leader>cd :lcd %:p:h<CR>
nnoremap <leader>gr :execute 'cd ' . systemlist('git rev-parse --show-toplevel')[0]<CR>

function! s:rel_to_git_root()
  let root = systemlist('git rev-parse --show-toplevel')[0]
  return substitute(expand('%:p'), '^'.escape(root, '\'), '', '')[1:]
endfunction
nnoremap <leader>fg :echo <SID>rel_to_git_root()<CR>

" Quickfix
nnoremap <silent> <leader>qo :copen<CR>
nnoremap <silent> <leader>qc :cclose<CR>
nnoremap <silent> ]q :cnext<CR>
nnoremap <silent> [q :cprev<CR>

" Splits
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

map <leader>o :setlocal spell! spelllang=en_us<CR>

" FZF & Telescope Fallback
cnoreabbrev ff FZF!
nnoremap S :%s//g<Left><Left>

" Suda write
let g:suda_smart_edit = 1
cnoreabbrev w!! SudaWrite

" File operations
function! s:NewFilePrompt() abort
  let base = expand('%:p:h')
  let path = input('New file path: ', base.'/','file')
  if empty(path) | return | endif
  call mkdir(fnamemodify(path, ':h'), 'p')
  execute 'edit' fnameescape(path)
  if empty(glob(path)) | write | endif
endfunction

function! s:NewDirPrompt() abort
  let base = expand('%:p:h')
  let path = input('New directory: ', base.'/','dir')
  if empty(path) | return | endif
  call mkdir(path, 'p')
  echo 'created ' . path
endfunction

nnoremap <leader>nf :call <SID>NewFilePrompt()<CR>

" Theme switcher
nnoremap <leader>th :lua if _G.CycleTheme then _G.CycleTheme() else print("Please restart Neovim to load the theme switcher") end<CR>
