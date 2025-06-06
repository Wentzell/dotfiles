# Build configuration
VERSION=20.1.6
BRANCH=llvmorg-$VERSION
INSTALL_DIR=$HOME/opt/llvm_$VERSION
SRC_DIR=$PWD
BUILD_DIR=$SRC_DIR/llvm_build
THREADS=50

## -- Get the Sources

# Shallow clone of llvm
cd $SRC_DIR
git clone https://github.com/llvm/llvm-project --branch $BRANCH --depth 1 -c advice.detachedHead=false

#cd $SRC_DIR
#cd llvm-project/llvm/tools/clang/tools
#mkdir templight
#git clone https://github.com/mikael-s-persson/templight templight
#echo "add_clang_subdirectory(templight)" >> CMakeLists.txt

#cd $SRC_DIR
#cd llvm-project/llvm/tools
#git clone https://github.com/facebookincubator/BOLT llvm-bolt
#cd ..
#patch -p 1 < tools/llvm-bolt/llvm.patch


## --  Build environment

# - GCC
export CC=gcc
export CXX=g++
export CFLAGS='-O3 -march=native'
export CXXFLAGS='-O3 -march=native'

## - Clang
#export CC=clang
#export CXX=clang++
#export CFLAGS='-O3 -march=broadwell'
#export CXXFLAGS='-stdlib=libc++ -O3 -march=broadwell'

#GCC_INSTALL_PREFIX=$(dirname $(which gcc))/../

## --  Build LLVM

mkdir -p $BUILD_DIR
cd $BUILD_DIR
# Cf. https://llvm.org/docs/CMake.html
# and https://llvm.org/docs/GettingStarted.html
cmake -GNinja \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
      -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;lld;lldb;pstl" \
      -DLLVM_ENABLE_RUNTIMES="compiler-rt;libcxx;libcxxabi;libunwind;openmp" \
      -DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
      -DBUILD_SHARED_LIBS=ON \
      -DLLVM_PARALLEL_COMPILE_JOBS=$THREADS \
      -DLLVM_PARALLEL_LINK_JOBS=$THREADS \
      -DLLVM_CCACHE_BUILD=ON \
      -DLLVM_ENABLE_PIC=ON \
      -DLLVM_ENABLE_THREADS=ON \
      -DLLVM_ENABLE_WARNINGS=OFF \
      -DLLVM_ENABLE_WERROR=OFF \
      -DLLVM_INCLUDE_EXAMPLES=OFF \
      -DLLVM_INCLUDE_TESTS=OFF \
      -DLLVM_INCLUDE_DOCS=OFF \
      -DLLVM_ENABLE_OCAMLDOC=OFF \
      -DLLVM_ENABLE_BINDINGS=OFF \
      -DLLVM_ENABLE_LIBCXX=OFF \
      -DLLVM_OPTIMIZED_TABLEGEN=ON \
      -DLLVM_USE_LINKER=lld \
      -DCMAKE_C_COMPILER=$CC \
      -DCMAKE_CXX_COMPILER=$CXX \
      -DLIBOMP_TSAN_SUPPORT=1 \
      -DLIBOMPTARGET_NVPTX_COMPUTE_CAPABILITIES="all" \
      -DCLANG_PYTHON_BINDINGS_VERSIONS="3.8;3.9;3.10;3.11;3.12;3.13" \
      -DLLVM_BINUTILS_INCDIR=/usr/include \
      -DLLDB_ENABLE_PYTHON=ON \
      -DLLDB_ENABLE_LIBEDIT=ON \
      ${SRC_DIR}/llvm-project/llvm
      #-DGCC_INSTALL_PREFIX=$GCC_INSTALL_PREFIX \
      #-DLLVM_ENABLE_RTTI=ON \
      #-DLLVM_USE_LINKER=gold \
      #-DLINK_POLLY_INTO_TOOLS=ON \
      #-DLLVM_BINUTILS_INCDIR="${SRC_DIR}/llvm/tools/binutils/include" \
      #-DLLVM_TARGETS_TO_BUILD="ARM;AArch64;PowerPC;X86" \
      #-DLLVM_VERSION_SUFFIX="-r${LLVM_SVN_REVISION:?}" \
      #-DCLANG_REPOSITORY_STRING="${URL_PREFIX}clang" \
      #-DCLANG_VENDOR="${VENDOR:+"${VENDOR} "}" \
      #-DCLANG_VERSION_SUFFIX="-r${CLANG_SVN_REVISION:?}" \

cmake --build .
ninja install

# --- Build and Install Include-what-you-use

cd $SRC_DIR
git clone https://github.com/include-what-you-use/include-what-you-use --branch clang_20 --depth 1

mkdir -p $SRC_DIR/iwyu_build
cd $SRC_DIR/iwyu_build

cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR -DCMAKE_PREFIX_PATH=$INSTALL_DIR $SRC_DIR/include-what-you-use
make -j $THREADS install
