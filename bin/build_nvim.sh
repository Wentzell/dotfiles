VERSION=v0.10.0
PREFIX=~/opt/neovim

git clone https://github.com/neovim/neovim --depth 1 --branch $VERSION
cd neovim

mkdir .deps && cd .deps
cmake ../cmake.deps
make
cd ..

mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PREFIX
make -j 20 install
