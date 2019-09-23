# Build configuration
RELEASE=trunk
INSTALL_DIR=$HOME/opt/gcc_${RELEASE}
SRC_DIR=$PWD/gcc_${RELEASE}
THREADS=60

# Shallow clone of gcc
git clone https://github.com/gcc-mirror/gcc --branch $RELEASE --depth 1 ${SRC_DIR}

# Build with gcc
export CC=gcc
export CXX=g++
export CFLAGS='-O3 -march=broadwell'
export CXXFLAGS='-O3 -march=broadwell'

cd ${SRC_DIR}
./contrib/download_prerequisites
./configure -v \
 	--prefix=$INSTALL_DIR \
  	--enable-shared \
	--enable-languages=c,c++,fortran \
	--with-system-zlib \
	--enable-thread \
       	--disable-multilib \
	--enable-checking=release \
	--enable-lto \
	#--program-suffix=-7   

make -j ${THREADS}
make -j ${THREADS} install
