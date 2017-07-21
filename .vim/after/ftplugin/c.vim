" Disable comment contiuation uf // comments
setlocal comments-=://
setlocal comments+=f://

" Set indention width
set shiftwidth=2

"---- Doxygen Style Comment blocks
"" Simple small comment line
:command! CommLineSmall 	:normal 1i/*<Esc>50i*<Esc>la/<CR>
"  Small comment line with text
:command! CommTLineSmall	:normal 1i/*<Esc>40i*<Esc>la/<Esc>20hi  
" Simple comment line
:command! CommLine 		:normal 50i=<Esc>,ciA<CR>
" Comment line with text
:command! CommTLine 		:normal 40i=<Esc>,ci18hi   


