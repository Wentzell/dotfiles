git clone https://github.com/vim/vim.git --depth 1
cd vim
./configure --with-features=huge \
            --enable-multibyte \
	    --enable-pythoninterp=yes \
	    --enable-python3interp=yes \
	    --enable-rubyinterp=yes \
	    --enable-luainterp=yes \
            --enable-gui=gtk2 \
            --enable-cscope \
	    --prefix=$HOME/opt/vim
make install
