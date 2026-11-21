" ===== Coc extensions =====
let g:coc_global_extensions = [
\ 'coc-tsserver',
\ 'coc-prettier',
\ '@yaegassy/coc-ruff',
\ '@yaegassy/coc-mypy',
\ 'coc-rust-analyzer',
\ 'coc-go',
\ 'coc-docker',
\ 'coc-jedi',
\ 'coc-clangd'
\ ]

let g:coc_user_config = extend(get(g:, 'coc_user_config', {}), {
\   'typescript.suggest.autoImports': v:true,
\   'javascript.suggest.autoImports': v:true,
\   'typescript.preferences.importModuleSpecifier': 'relative',
\   'javascript.preferences.importModuleSpecifier': 'relative',
\   'typescript.updateImportsOnFileMove.enabled': 'always',
\   'javascript.updateImportsOnFileMove.enabled': 'always',
\   'suggest.noselect': v:false
\ }, 'force')

let g:coc_user_config = extend(get(g:, 'coc_user_config', {}), {
\  'clangd.enabled': v:true,
\  'clangd.path': 'clangd',
\  'clangd.arguments': [
\    '--background-index',
\    '--completion-style=detailed',
\    '--query-driver=/usr/bin/clang*,/usr/bin/gcc*,/usr/bin/g++*,/usr/local/bin/clang*,/usr/local/bin/gcc*,/usr/local/bin/g++*'
\  ],
\  'clangd.compilationDatabaseCandidates': [
\    '${workspaceFolder}/build',
\    '${workspaceFolder}/build/debug',
\    '${workspaceFolder}/build/release',
\    '${workspaceFolder}/cmake-build-debug',
\    '${workspaceFolder}/cmake-build-release',
\    '${workspaceFolder}/out/build',
\    '${workspaceFolder}'
\  ],
\  'clangd.fallbackFlags': [
\    '-std=c++20',
\    '-Wall',
\    '-Wextra',
\    '-Isrc',
\    '-Iinclude'
\  ],
\  'clangd.disableProgressNotifications': v:true
\}, 'force')

let s:language_servers = get(get(g:, 'coc_user_config', {}), 'languageserver', {})

if executable('prisma-language-server')
  let s:language_servers['prisma'] = {
  \ 'command': 'prisma-language-server',
  \ 'args': ['--stdio'],
  \ 'filetypes': ['prisma'],
  \ 'rootPatterns': ['schema.prisma'],
  \ 'trace.server': 'verbose'
  \ }
endif

let g:coc_user_config = extend(get(g:, 'coc_user_config', {}), {
\ 'languageserver': s:language_servers
\}, 'force')

if !exists('g:coc_node_path')
  let s:nodes = glob('~/.nvm/versions/node/v20*/bin/node', 1, 1)
  if len(s:nodes) > 0 | let g:coc_node_path = s:nodes[0] | endif
endif

let g:coc_user_config = extend(get(g:, 'coc_user_config', {}), {
\  'python.venvPath': '.',
\  'python.venv': '.venv',
\  'python.analysis.autoImportCompletions': v:false,
\  'ruff.enable': v:true,
\  'ruff.nativeServer': v:true,
\  'ruff.path': ['.venv/bin/ruff', 'ruff'],
\  'ruff.interpreter': ['.venv/bin/python'],
\  'mypy-type-checker.enable': v:true,
\  'mypy-type-checker.useDmypy': v:true,
\  'mypy-type-checker.cwd': '${workspaceFolder}',
\  'mypy-type-checker.venvPath': '.',
\  'mypy-type-checker.venv': '.venv',
\  'mypy-type-checker.executable': '.venv/bin/mypy',
\  'jedi.enable': v:true
\}, 'force')

nmap <leader>ac  <Plug>(coc-codeaction)
nmap <leader>qf  <Plug>(coc-fix-current)
nmap <silent> gd <Plug>(coc-definition)
nnoremap <C-a> <C-o>
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)
nnoremap <C-d> <Plug>(coc-definition)
nnoremap <silent> <C-r> <Plug>(coc-references)
nmap <leader>rn  <Plug>(coc-rename)

nnoremap <leader>mi :call CocActionAsync('codeAction', '', ['source.addMissingImports.ts'])<CR>
nnoremap <leader>oi :call CocActionAsync('runCommand', 'editor.action.organizeImport')<CR>

inoremap <silent><expr> <C-Space> coc#refresh()
inoremap <silent><expr> <Tab> pumvisible() ? "\<C-n>" : "\<Tab>"
inoremap <silent><expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"
inoremap <silent><expr> <CR> pumvisible() ? coc#pum#confirm() : "\<CR>"