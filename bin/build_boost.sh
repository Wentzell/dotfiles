# Build configuration
RELEASE=boost-1.71.0_gcc
INSTALL_DIR=$HOME/opt/boost-1.71.0_gcc
THREADS=40

# Shallow clone of boost
git clone https://github.com/boostorg/boost --branch boost-1.71.0 --depth 1 --recursive 
cd boost

# # === Build using clang
export CC=clang
export CXX=clang++
export CXXFLAGS='-O3 -march=native -stdlib=libc++'
export LDFLAGS='-stdlib=libc++'
# Cf. https://github.com/boostorg/boost/wiki/Getting-Started%3A-Overview#installing-boost
./bootstrap.sh --with-toolset=clang
./b2 toolset=clang cxxflags="$CXXFLAGS" linkflags="$LDFLAGS" install --prefix=${INSTALL_DIR} -j ${THREADS}

# # === Build using gcc
# export CC=gcc
# export CXX=g++
# export CXXFLAGS='-O3 -march=native'
# ./bootstrap.sh
# ./b2 toolset=clang cxxflags="$CXXFLAGS" install --prefix=${INSTALL_DIR} -j ${THREADS}
