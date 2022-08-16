"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"  My .VIMRC 	\O/						"
"								"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

"-------------------------------------- Load plugins ------------------------------------------

call plug#begin()

Plug 'vim-scripts/GrepCommands'
Plug 'scrooloose/nerdcommenter'
Plug 'preservim/tagbar'
Plug 'scrooloose/nerdtree'
Plug 'chrisbra/Recover.vim'
Plug 'octol/vim-cpp-enhanced-highlight'
Plug 'tpope/vim-fugitive'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'altercation/vim-colors-solarized'

if has('nvim')
  Plug 'neovim/nvim-lspconfig'
  Plug 'chrisbra/matchit'

  " -- Auto Completion --
  Plug 'hrsh7th/nvim-cmp', { 'branch': 'main' }
  Plug 'hrsh7th/cmp-nvim-lsp', { 'branch': 'main' }
  Plug 'saadparwaiz1/cmp_luasnip'
  Plug 'L3MON4D3/LuaSnip'
  Plug 'github/copilot.vim'
  Plug 'nvim-lua/plenary.nvim'
  Plug 'CopilotC-Nvim/CopilotChat.nvim'

else
  " vim only plugins
  Plug 'vim-scripts/AnsiEsc.vim'
  Plug 'derekwyatt/vim-fswitch'

  Plug 'autozimu/LanguageClient-neovim', {
      \ 'branch': 'dev',
      \ 'do': 'bash install.sh',
      \ }
endif

call plug#end()

"-------------------------------------- General Settings ------------------------------------------

syntax on			" Syntax highlighting on
filetype plugin indent on	" Indenting globally on
set shiftwidth=2		" Set indent shift
set backspace=2			" Make backspace work normally
set nomore			" Do not prompt for 'more'
set vb t_vb=			" Remove annying beep on mac

" Airline theme
let g:airline_theme='solarized'
let g:airline_solarized_bg='dark'
"Install e.g. Powerline Source Code Pro Font
let g:airline_powerline_fonts = 1
if !exists('g:airline_symbols')
  let g:airline_symbols = {}
endif
let g:airline_symbols.space = "\ua0"
let g:airline#extensions#tabline#show_buffers = 0

"Tagbar
let g:tagbar_width = 25

" Settings for solarized color scheme
set t_Co=256
set background=dark
set notermguicolors
silent! colorscheme solarized

" Enable highlighting of matching angle braces
set mps+=<:>

" My Status Line
set statusline=%t[%{strlen(&fenc)?&fenc:'none'},%{&ff}]%h%m%r%y%=%c,%l/%L\ %P
set laststatus=2		" Always display status bar
set hidden			" Can hide changed buffers!
set number 			" Show line numbers

" Remove all trailing whitespaces
:command! Delwsp :%s/\s\+$//e

let g:clang_format#command = 'clang-format'

" fix replace color highlight
:hi incsearch term=standout cterm=standout ctermfg=9 ctermbg=7 gui=reverse

"-------------------------------------- Custom Commands ------------------------------------------

"Command Make will call make and then open quickfix window
if !has('nvim')
  autocmd BufReadPost quickfix AnsiEsc
endif

set makeprg=cmake
:command! -nargs=* Make :make --build build_mac <args> | cwindow 15

"-------------------------------------- Key Mappings ------------------------------------------

" rebind leader key and escape
let mapleader = ","
inoremap ;; <Esc>
xnoremap ;; <Esc>

" easy jump between buffers
nnoremap <leader><leader>e 	:b#<cr>
xnoremap <leader><leader>e 	:b#<cr>

" easy copy/paste to clipboard
xnoremap <leader><leader>y 	"*y
nnoremap <leader><leader>p 	"*p
xnoremap <leader><leader>p 	"*p

" simple scrolling through file
nnoremap ;j 	<C-D>
nnoremap ;k 	<C-U>
xnoremap ;j 	<C-D>
xnoremap ;k 	<C-U>

" change window mode mappings
noremap <leader><leader> 	<C-W>
noremap <leader><leader>s	<C-W>s
noremap <leader><leader>v	<C-W><C-V>
noremap <leader><leader>x	<C-W>c
noremap <leader><leader>c	<C-W>x
noremap <leader>m	        <C-W><
noremap <leader>.	        <C-W>>

" nerdtree
noremap <leader><leader>n 	:NERDTreeToggle<cr>
noremap <leader><leader>t       :TagbarToggle<cr>

" Build program
autocmd Syntax c,cpp map <buffer> 'll :Make<cr><cr><cr>

";n for next error
nnoremap ;n	:cn<cr>
nnoremap ;p	:cp<cr>

" search highlighting on / off
nnoremap ;h	:set hlsearch!<cr>

" Set wrapping and fix movement keys!
noremap <silent> <Leader>w :call ToggleWrap()<CR>
function ToggleWrap()
  if &wrap
    echo "Wrap OFF"
    setlocal nowrap
    set virtualedit=all
    silent! nunmap <buffer> k
    silent! nunmap <buffer> j
    silent! nunmap <buffer> 0
    silent! nunmap <buffer> $
  else
    echo "Wrap ON"
    setlocal wrap linebreak nolist
    set virtualedit=
    setlocal display+=lastline
    noremap  <buffer> <silent> k   gk
    noremap  <buffer> <silent> j   gj
    noremap  <buffer> <silent> 0   g0
    noremap  <buffer> <silent> $   g$
  endif
endfunction

"-------------------------------------- File Type Autocommands ------------------------------------------

au BufNewFile,BufRead	*MAKE*	set filetype=make		" set files with MAKE in name to make type

"-------------------------------------- Folding ------------------------------------------

set foldmethod=marker foldlevelstart=0 foldnestmax=1
autocmd Syntax c,cpp setlocal foldmethod=syntax 	" Enable Syntax folding
autocmd Syntax c,cpp normal zR			        " Start unfolded

"-------------------------------------- General Coding Config ------------------------------------------

set wildmenu
inoremap <C-n> <C-x><C-o>

if !has('nvim')
  "let g:LanguageClient_loggingFile = expand('~/.vim/LanguageClient.log')
  "let g:LanguageClient_loggingLevel = 'DEBUG'
  let g:LanguageClient_diagnosticsList = "Disabled" " We do not want to populate the quickfix window
  let g:LanguageClient_rootMarkers = ['.git']
  let g:LanguageClient_loadSettings = 1
  let g:LanguageClient_serverCommands = {
        \ 'python': ['pyright'],
        \ 'c': ['clangd',
        \	      '--all-scopes-completion',
        \	      '--background-index',
        \	      '--completion-style=bundled',
        \	      '--header-insertion=iwyu',
        \	      '--clang-tidy',
        \	      '--suggest-missing-includes'],
        \ 'cpp': ['clangd',
        \	      '--all-scopes-completion',
        \	      '--background-index',
        \	      '--completion-style=bundled',
        \	      '--header-insertion=iwyu',
        \	      '--clang-tidy',
        \	      '--suggest-missing-includes'],
        \ }

  " --- Language Server Bindings
  autocmd Syntax c,cpp,python nnoremap <buffer> <C-]> :call LanguageClient#textDocument_definition()<CR>
  autocmd Syntax c,cpp,python xnoremap <buffer> <C-]> :call LanguageClient#textDocument_definition()<CR>
  autocmd Syntax c,cpp,python nnoremap <buffer> <C-h> :call LanguageClient#textDocument_rename()<CR>
  autocmd Syntax c,cpp,python xnoremap <buffer> <C-h> :call LanguageClient#textDocument_rename()<CR>

  " --- Code Completion
  set omnifunc=LanguageClient#complete
  set completefunc=LanguageClient#complete
  let g:LanguageClient_autoStart = 1
  let g:LanguageClient_hoverPreview = 'auto'
  let g:LanguageClient_diagnosticsEnable = 1

endif


"-------------------------------------- Python Specific Stuff ------------------------------------------
"
autocmd FileType python set shiftwidth=4

" --- Config for yapf
autocmd Syntax python nnoremap <buffer> == :YAPF<cr>
autocmd Syntax python xnoremap <buffer> == :YAPF<cr>

"-------------------------------------- Cpp Specific Stuff ------------------------------------------

" --- Config for clang-format plugin
autocmd Syntax c,cpp nnoremap <buffer> == :call LanguageClient_textDocument_formatting()<CR>
autocmd Syntax c,cpp xnoremap <buffer> == :call LanguageClient_textDocument_formatting()<CR>

" set up file switch for fswitch plugin
au! BufEnter *.cpp let b:fswitchdst = 'hpp'
au! BufEnter *.hpp let b:fswitchdst = 'cpp'

" --- FSwitch bindings
" Switch to the file and load it into the current window >
nmap <silent> <Leader>of :FSHere<cr>


"-------------------------------------- Latex Specific Stuff ------------------------------------------
"

autocmd Syntax tex nnoremap 'll <Leader>ll
:command! Myspell :setlocal spell spelllang=en_us <bar> :syntax spell toplevel


" --- Presentation mode
"let g:airline_solarized_bg='light'
"set background=light
