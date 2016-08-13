
" Set indention width
set shiftwidth=3

:command! CompileTex	:!rubber -d %; evince *.pdf	

nnoremap <F5>	:CompileTex<cr>
