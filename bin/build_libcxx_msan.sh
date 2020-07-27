# Build configuration
RELEASE=llvmorg-10.0.0
INSTALL_DIR=$HOME/opt/libcxx_10.0.0_msan
SRC_DIR=$PWD
BUILD_DIR=${SRC_DIR}/libcxx_build
THREADS=40


## -- Get the Sources

# Shallow clone of llvm
cd ${SRC_DIR}
git clone https://github.com/llvm/llvm-project --branch $RELEASE --depth 1 -c advice.detachedHead=false


## --  Build environment

export CFLAGS='-O3 -march=broadwell'
export CXXFLAGS='-O3 -march=broadwell'

# - GCC
#export CC=gcc
#export CXX=g++

# - Clang
export CC=clang
export CXX=clang++


## --  Build LLVM

mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}
# Cf. https://llvm.org/docs/CMake.html
# and https://llvm.org/docs/GettingStarted.html
# and https://github.com/google/sanitizers/wiki/MemorySanitizerLibcxxHowTo
cmake -GNinja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
      -DLLVM_ENABLE_PROJECTS="libcxx;libcxxabi" \
      -DLLVM_PARALLEL_COMPILE_JOBS="${THREADS}" \
      -DLLVM_PARALLEL_LINK_JOBS="${THREADS}" \
      -DLLVM_ENABLE_PIC=ON \
      -DLLVM_USE_SANITIZER=MemoryWithOrigins \
      "${SRC_DIR}/llvm-project/llvm"

cmake --build . -- cxx cxxabi
ninja install
