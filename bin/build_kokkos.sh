# Build configuration
RELEASE=develop
INSTALL_DIR=$HOME/opt/kokkos_${RELEASE}
SRC_DIR=$PWD
BUILD_DIR=${SRC_DIR}/kokkos_build
THREADS=60

# Shallow clone of kokkos
cd ${SRC_DIR}
git clone https://github.com/kokkos/kokkos --branch $RELEASE --depth 1

# Build with clang
export CC=clang
export CXX=clang++
export CFLAGS='-O3 -march=broadwell'
export CXXFLAGS='-O3 -march=broadwell'
#GCC_INSTALL_PREFIX=$(dirname $(which gcc))/../
#export CXXFLAGS="--gcc-toolchain=${GCC_INSTALL_PREFIX} -stdlib=libstdc++"

mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}

cmake ../kokkos -DCMAKE_BUILD_TYPE=Release \
  		-DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
		-DCMAKE_CXX_STANDARD=17 \
          	-DKokkos_ENABLE_TESTS=ON \
		-DKokkos_ENABLE_SERIAL=ON \
	  	-DKokkos_ENABLE_CUDA=ON \
		-DKokkos_ENABLE_CUDA_LAMBDA=ON \
		-DKokkos_ARCH_VOLTA70=ON

          	#-DKokkos_ENABLE_TESTS=ON \
		#-DKokkos_ARCH=Pascal61
		#-DKokkos_ENABLE_PTHREAD=ON \
		#-DKokkos_ENABLE_OPENMP=ON \
		#-DKokkos_ENABLE_CXX11=ON \

make -j ${THREADS}
ctest -j ${THREADS}
make install
export CMAKE_INSTALL_PREFIX=${INSTALL_DIR}/lib64/cmake/Kokkos:$CMAKE_INSTALL_PREFIX

# Shallow clone of kokkos kernels (use my clone with cmake fixes)
cd ${SRC_DIR}
git clone github:Wentzell/kokkos-kernels --branch cmake-overhaul --depth 1
#git clone github:kokkos/kokkos-kernels --branch cmake-overhaul --depth 1

BUILD_DIR=${SRC_DIR}/kokkos-kernel_build
mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}

export LDFLAGS='-lpthread -lcublas'
cmake ../kokkos-kernels -DCMAKE_INSTALL_PREFIX=${INSTALL_DIR} \
       	-DCMAKE_BUILD_TYPE=Release \
  	-DKokkos_ENABLE_PTHREAD=OFF \
	-DKokkos_ENABLE_OPENMP=OFF
	#-DKokkosKernels_ENABLE_TESTS=ON

make -j ${THREADS}
#ctest -j ${THREADS}
make install
# CMAKE_INSTALL_PREFIX still improper for KokkosKernels
export CMAKE_INSTALL_PREFIX=${INSTALL_DIR}/lib/cmake:$CMAKE_INSTALL_PREFIX
