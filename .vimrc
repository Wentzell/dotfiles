"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
"  My .VIMRC 	\O/						" 
"								"
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

"-------------------------------------- Load plugins ------------------------------------------

set nocompatible
filetype off
set rtp+=~/.vim/bundle/Vundle.vim/
call vundle#begin()"

" Let Vundle manage itself
Plugin 'VundleVim/Vundle.vim'

" Load Plugins ( from github.com )
Plugin 'vim-scripts/GrepCommands'
Plugin 'tpope/vim-surround'
Plugin 'tpope/vim-repeat'
Plugin 'Latex-Box-Team/Latex-Box'
Plugin 'scrooloose/nerdcommenter'
Plugin 'chrisbra/Recover.vim'
Plugin 'octol/vim-cpp-enhanced-highlight'
Plugin 'altercation/vim-colors-solarized'
Plugin 'derekwyatt/vim-fswitch'
Plugin 'rhysd/vim-clang-format'
Plugin 'vim-scripts/AnsiEsc.vim'

call vundle#end()

"-------------------------------------- GENERAL SETTINGS ------------------------------------------

syntax on			" Syntax highlighting on
filetype plugin indent on	" Indenting globally on
set shiftwidth=4		" Set indent shift

set wildmenu			" Always use auto-complete menu

" My Status Line
set statusline=%t[%{strlen(&fenc)?&fenc:'none'},%{&ff}]%h%m%r%y%=%c,%l/%L\ %P	
set laststatus=2		" Always display status bar		
set hidden			" Can hide changed buffers!
set number 			" Show line numbers 

" Settings for solarized color scheme
set t_Co=256			
set background=dark
colorscheme solarized 

" fix replace color highlight
:hi incsearch term=standout cterm=standout ctermfg=9 ctermbg=7 gui=reverse

"-------------------------------------- CUSTOM COMMANDS ------------------------------------------

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
:command! Mdb		:make | copen
" Insert templates
:command! Tcpp		:r ~/.vim/templates/templ.cpp
:command! Tmain		:r ~/.vim/templates/main.cpp
:command! Tclass	:r ~/.vim/templates/class.cpp
:command! Th		:r ~/.vim/templates/templ.h
:command! Ttex		:r ~/.vim/templates/templ.tex

"Command Make will call make and then open quickfix window
autocmd BufReadPost quickfix AnsiEsc
set makeprg=$HOME/.vim/mymake.sh
:command! -nargs=* Make :make -j 8 <args> | cwindow

"-------------------------------------- KEY MAPPINGS ------------------------------------------

" rebind leader key and escape 
let mapleader = ","
inoremap ;; <Esc>
vnoremap ;; <Esc>

" easy copy/paste to clipboard
vnoremap <leader><leader>y 	"*y
nnoremap <leader><leader>p 	"*p
vnoremap <leader><leader>p 	"*p

" simple scrolling through file
nnoremap ;j 	<C-D>
nnoremap ;k 	<C-U>
vnoremap ;j 	<C-D>
vnoremap ;k 	<C-U>

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
autocmd Syntax c,cpp map 'll :Make -C build<cr><cr><cr>

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
vnoremap <C-r> "hy:%s/<C-r>h//gc<left><left><left>

"-------------------------------------- FILE TYPE AUTOCOMMANDS ------------------------------------------

au BufNewFile,BufRead	*.plt	set filetype=gnuplot		" set plt files to gnuplot type
au BufNewFile,BufRead	*MAKE*	set filetype=make		" set files with MAKE in name to make type

"-------------------------------------- FOLDING  ------------------------------------------

autocmd Syntax c,cpp,vim,xml,html,xhtml setlocal foldmethod=syntax 	" Enable Syntax folding
autocmd Syntax c,cpp,vim,xml,html,xhtml,perl normal zR			" Start unfolded

"-------------------------------------- CPP SPECIFIC STUFF ------------------------------------------

" --- Config for clang-format plugin
autocmd Syntax c,cpp nnoremap == :ClangFormat<cr>
autocmd Syntax c,cpp vnoremap == :ClangFormat<cr>
" Specify command in shell
let g:clang_format#command = 'clang-format'
" Detect and apply style-file .clang-format or _clang-format
let g:clang_format#detect_style_file = 1


" set up file switch for fswitch plugin
"au! BufEnter *.cpp let b:fswitchdst = 'h' | let b:fswitchlocs = '../include'
"au! BufEnter *.h let b:fswitchdst = 'cpp' | let b:fswitchlocs = '../src'
au! BufEnter *.cpp let b:fswitchdst = 'hpp'
au! BufEnter *.hpp let b:fswitchdst = 'cpp'

" --- FSwitch bindings
" Switch to the file and load it into the current window >
nmap <silent> <Leader>of :FSHere<cr>
"Switch to the file and load it into the window on the right >
nmap <silent> <Leader>ol :FSRight<cr>
"Switch to the file and load it into a new window split on the right >
nmap <silent> <Leader>oL :FSSplitRight<cr>
"Switch to the file and load it into the window on the left >
nmap <silent> <Leader>oh :FSLeft<cr>
"Switch to the file and load it into a new window split on the left >
nmap <silent> <Leader>oH :FSSplitLeft<cr>
"Switch to the file and load it into the window above >
nmap <silent> <Leader>ok :FSAbove<cr>
"Switch to the file and load it into a new window split above >
nmap <silent> <Leader>oK :FSSplitAbove<cr>
"Switch to the file and load it into the window below >
nmap <silent> <Leader>oj :FSBelow<cr>
"Switch to the file and load it into a new window split below >
nmap <silent> <Leader>oJ :FSSplitBelow<cr>

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

"-------------------------------------- LATEX SPECIFIC STUFF ------------------------------------------
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

:command! Myspell :setlocal spell spelllang=en_us <bar> :syntax spell toplevel

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
