# Build configuration
RELEASE=boost-1.71.0
INSTALL_DIR=$HOME/opt/boost-1.71.0
THREADS=40

# Shallow clone of boost
git clone https://github.com/boostorg/boost --branch boost-1.71.0 --depth 1 --recursive 
cd boost

# Build with clang
export CC=clang
export CXX=clang++
export CFLAGS='-O3 -march=broadwell -stdlib=libc++'
export CXXFLAGS='-O3 -march=broadwell -stdlib=libc++'

# Cf. https://github.com/boostorg/boost/wiki/Getting-Started%3A-Overview#installing-boost
./bootstrap.sh --with-toolset=clang
./b2 toolset=clang install --prefix=${INSTALL_DIR} -j ${THREADS}
