"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"  My .VIMRC 	\O/						"
"								"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

"-------------------------------------- Load plugins ------------------------------------------{{{

call plug#begin()

Plug 'vim-scripts/GrepCommands'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'Latex-Box-Team/Latex-Box'
Plug 'scrooloose/nerdcommenter'
Plug 'chrisbra/Recover.vim'
Plug 'octol/vim-cpp-enhanced-highlight'
Plug 'altercation/vim-colors-solarized'
Plug 'derekwyatt/vim-fswitch'
Plug 'vim-scripts/AnsiEsc.vim'
Plug 'tpope/vim-fugitive'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'autozimu/LanguageClient-neovim', {
    \ 'branch': 'next',
    \ 'do': 'bash install.sh',
    \ }

call plug#end()
"}}}
"-------------------------------------- General Settings ------------------------------------------{{{

syntax on			" Syntax highlighting on
filetype plugin indent on	" Indenting globally on
set shiftwidth=2		" Set indent shift
set backspace=2			" Make backspace work normally
set nomore			" Do not prompt for 'more'

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

" My Status Line
set statusline=%t[%{strlen(&fenc)?&fenc:'none'},%{&ff}]%h%m%r%y%=%c,%l/%L\ %P
set laststatus=2		" Always display status bar
set hidden			" Can hide changed buffers!
set number 			" Show line numbers

" Settings for solarized color scheme
set t_Co=256
set background=dark
colorscheme solarized

" Remove all trailing whitespaces on write
"autocmd BufWritePre * %s/\s\+$//e
:command! Delwsp :%s/\s\+$//e

let g:clang_format#command = 'clang-format'

" fix replace color highlight
:hi incsearch term=standout cterm=standout ctermfg=9 ctermbg=7 gui=reverse
"}}}
"-------------------------------------- Custom Commands ------------------------------------------{{{

" Simple small comment line
:command! CommLineSmall 	:normal 80i-<Esc>,ciA<cr>
"  Small comment line with text
:command! CommTLineSmall	:normal 80i-<Esc>,ci40hi
" Simple comment line
:command! CommLine 	:normal 70i=<Esc>,ciA<cr>
" Comment line with text
:command! CommTLine 	:normal 70i=<Esc>,ci35hi
" Start Doxygen multiline comment
:command! DoxComm	:normal i/**<cr><cr>/<Esc>ka<TAB>
" Build file and open quickfix window
:command! Mdb		:make | cwindow 15
" Insert templates
:command! Ttest		:r ~/.vim/templates/test.cpp
:command! TtestF	:r ~/.vim/templates/test_F.cpp
:command! Tpytest	:r ~/.vim/templates/test.py
:command! TCMake	:r ~/.vim/templates/CMakeLists.txt
:command! Ttex		:r ~/.vim/templates/templ.tex

"Command Make will call make and then open quickfix window
autocmd BufReadPost quickfix AnsiEsc
"set makeprg=$HOME/bin/pymake
set makeprg=make
:command! -nargs=* Make :make -j 60 <args> | cwindow 15
"}}}
"-------------------------------------- Key Mappings ------------------------------------------{{{

" rebind leader key and escape
let mapleader = ","
inoremap ;; <Esc>
xnoremap ;; <Esc>

" easy copy/paste to clipboard
xnoremap <leader><leader>y 	"+y
nnoremap <leader><leader>p 	"+p
xnoremap <leader><leader>p 	"+p

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

" comment insertions
nmap <Leader>chl 	:CommLineSmall<cr>
nmap <Leader>ctl 	:CommTLineSmall<cr>
nmap <Leader>Chl 	:CommLine<cr>
nmap <Leader>Ctl 	:CommTLine<cr>
nmap <Leader>dc 	:DoxComm<cr>

" automatically add closing brackets
inoremap {      {}<Left>
inoremap {<cr>  {<cr>}<Esc>O
inoremap {{     {
inoremap {}     {}

"Just press F5 to make your program:
map <F5> :Make run<cr><cr><cr>
autocmd Syntax c,cpp map <buffer> 'll :Make -s -C build<cr><cr><cr>

";n for next error
nnoremap ;n	:cn<cr>
nnoremap ;p	:cp<cr>

" create and goto file under cursor
map <leader>gf :e <cfile><cr>

" reload vimrc and automatically do so if .vimrc saved
nmap <Leader>vrc :so $MYVIMRC<cr>
autocmd! bufwritepost .vimrc source %

" search highlighting on / off
nnoremap ;h	:set hlsearch!<cr>

" replace selected text
xnoremap <C-r> "hy:%s/<C-r>h//gc<left><left><left>

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
"}}}
"-------------------------------------- File Type Autocommands ------------------------------------------{{{

au BufNewFile,BufRead	*.plt	set filetype=gnuplot		" set plt files to gnuplot type
au BufNewFile,BufRead	*MAKE*	set filetype=make		" set files with MAKE in name to make type
"}}}
"-------------------------------------- Folding ------------------------------------------{{{

set foldmethod=marker foldlevelstart=0 foldnestmax=1
autocmd Syntax c,cpp setlocal foldmethod=syntax 	" Enable Syntax folding
autocmd Syntax c,cpp normal zR			        " Start unfolded
"}}}
"-------------------------------------- General Coding Config ------------------------------------------{{{
"
"let g:LanguageClient_loggingFile = expand('~/.vim/LanguageClient.log')
let g:LanguageClient_diagnosticsList = "Disabled" " We do not want to populate the quickfix window
let g:LanguageClient_serverCommands = {
      \ 'python': ['pyls'],
      \ 'c': ['clangd',
      \       '--compile-commands-dir='.getcwd().'/build',
      \	      '--all-scopes-completion',
      \	      '--background-index',
      \	      '--clang-tidy',
      \	      '--completion-style=bundled',
      \	      '--header-insertion=iwyu',
      \	      '--suggest-missing-includes'],
      \ 'cpp': ['clangd',
      \       '--compile-commands-dir='.getcwd().'/build',
      \	      '--all-scopes-completion',
      \	      '--background-index',
      \	      '--clang-tidy',
      \	      '--completion-style=bundled',
      \	      '--header-insertion=iwyu',
      \	      '--suggest-missing-includes'],
      \ }

" --- Language Server Bindings
autocmd Syntax c,cpp,python nnoremap <buffer> <C-]> :call LanguageClient#textDocument_definition()<CR>
autocmd Syntax c,cpp,python xnoremap <buffer> <C-]> :call LanguageClient#textDocument_definition()<CR>
autocmd Syntax c,cpp,python nnoremap <buffer> <C-h> :call LanguageClient#textDocument_rename()<CR>
autocmd Syntax c,cpp,python xnoremap <buffer> <C-h> :call LanguageClient#textDocument_rename()<CR>

" --- Code Completion
set omnifunc=syntaxcomplete#Complete
set completefunc=LanguageClient#complete
set wildmenu
inoremap <C-n> <C-x><C-o>
let g:LanguageClient_autoStart = 1
let g:LanguageClient_hoverPreview = 'auto'
let g:LanguageClient_diagnosticsEnable = 1
"}}}
"-------------------------------------- Python Specific Stuff ------------------------------------------{{{
"
autocmd FileType python set shiftwidth=4

" --- Config for yapf
autocmd Syntax python nnoremap <buffer> == :YAPF<cr>
autocmd Syntax python xnoremap <buffer> == :YAPF<cr>
"}}}
"-------------------------------------- Cpp Specific Stuff ------------------------------------------{{{

" --- Config for clang-format plugin
autocmd Syntax c,cpp nnoremap <buffer> == :call LanguageClient_textDocument_formatting()<CR>
autocmd Syntax c,cpp xnoremap <buffer> == :call LanguageClient_textDocument_formatting()<CR>

" --- Enable highlighting of matching angle braces
autocmd Syntax c,cpp set mps+=<:>

" set up file switch for fswitch plugin
"au! BufEnter *.cpp let b:fswitchdst = 'h' | let b:fswitchlocs = '../include'
"au! BufEnter *.h let b:fswitchdst = 'cpp' | let b:fswitchlocs = '../src'
au! BufEnter *.cpp let b:fswitchdst = 'hpp'
au! BufEnter *.hpp let b:fswitchdst = 'cpp'

" --- FSwitch bindings
" Switch to the file and load it into the current window >
nmap <silent> <Leader>of :FSHere<cr>

" Translate Mathematica cpp expressions to correct expression
function! Math2Cpp()
   :s/\\\[\(\w\{-}\)\]/\1/ge
   :s/Beta/BETA/ge
   :s/CapitalLambda/Lam/ge
   :s/\(\d\+\)\./\1/ge
   :s/\(\d\+\)/\1.0/ge
   :s/Power/pow/ge
   :s/Pi/PI/ge
   :s/ArcTanh/atanh/ge
   :s/ArcTan/atan/ge
   :s/HeavisideThetan/Theta/ge
   :s/Log/log/ge
   :s/Abs/abs/ge
endfunction
"}}}
"-------------------------------------- Latex Specific Stuff ------------------------------------------{{{
"
let g:LatexBox_viewer = 'zathura'
let g:LatexBox_latexmk_options = "-pdflatex='pdflatex -synctex=1 \%O \%S'"
let g:LatexBox_ignore_warnings = ['Underfull',
				\ 'Overfull',
				\ 'deprecated',
				\ 'fancyhdr',
				\ 'titlesec',
				\ 'hyperref',
				\ 'minitoc',
				\ 'Font shape',
				\ 'Some font shapes',
				\ 'Empty \`thebibliography',
				\ 'specifier changed to',
				\ 'Package amsmath Warning']

nnoremap <F9>   :exec "!zathura ".LatexBox_GetOutputFile() line('.')  col('.') "%"<cr><cr>

function! SyncTexForward()
   let servername = substitute( LatexBox_GetOutputFile(), '.*/\(.\{-}\)\.pdf', '\U\1', 'g' )
   let execstr = "silent !zathura -x 'gvim -v --servername ". servername ." --remote +\\\%{line} \\\%{input}' --synctex-forward ".line(".").":".col('.').":% ". LatexBox_GetOutputFile() ." 2> /dev/null &"
   exec execstr
   :redraw!
endfunction

nmap <Leader>f :call SyncTexForward()<CR>

:command! Myspell :setlocal spell spelllang=en_us <bar> :syntax spell toplevel"}}}
