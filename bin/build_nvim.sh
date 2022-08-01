VERSION=v0.7.2
PREFIX=~/opt/neovim

git clone https://github.com/neovim/neovim --depth 1 --branch $VERSION
cd neovim

mkdir .deps && cd .deps
cmake ../third-party # change to ../cmake.deps for v0.8+
make
cd ..

mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=$PREFIX
make -j 20 install
