# Build configuration
RELEASE=llvmorg-9.0.0
INSTALL_DIR=$HOME/opt/llvm_9.0.0
SRC_DIR=$PWD
BUILD_DIR=${SRC_DIR}/llvm_build
THREADS=10

# Shallow clone of llvm
cd ${SRC_DIR}
git clone https://github.com/llvm/llvm-project --branch $RELEASE --depth 1

#cd ${SRC_DIR}
#cd llvm-project/llvm/tools/clang/tools
#mkdir templight
#git clone https://github.com/mikael-s-persson/templight templight
#echo "add_clang_subdirectory(templight)" >> CMakeLists.txt

#cd ${SRC_DIR}
#cd llvm-project/llvm/tools
#git clone https://github.com/facebookincubator/BOLT llvm-bolt
#cd ..
#patch -p 1 < tools/llvm-bolt/llvm.patch

# Build with gcc
export CC=gcc
export CXX=g++
export CXXFLAGS=''
GCC_INSTALL_PREFIX=$(dirname $(which gcc))/../

mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}
# Cf. https://llvm.org/docs/CMake.html
# and https://llvm.org/docs/GettingStarted.html
cmake -DCMAKE_BUILD_TYPE=Release \
      -DGCC_INSTALL_PREFIX=${GCC_INSTALL_PREFIX} \
      -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;lld;polly;compiler-rt;openmp;libcxx;libcxxabi" \
      -DCMAKE_C_FLAGS="-O3" \
      -DCMAKE_CXX_FLAGS="-O3" \
      -DLLVM_CCACHE_BUILD=ON \
      -DLLVM_ENABLE_PIC=ON \
      -DCMAKE_INSTALL_PREFIX="${INSTALL_DIR}" \
      -DLLVM_PARALLEL_COMPILE_JOBS="${THREADS}" \
      -DLLVM_PARALLEL_LINK_JOBS="${THREADS}" \
      -DLLVM_ENABLE_THREADS=ON \
      -DLLVM_ENABLE_WARNINGS=OFF \
      -DLLVM_ENABLE_WERROR=OFF \
      -DLLVM_INCLUDE_EXAMPLES=OFF \
      -DLLVM_INCLUDE_TESTS=OFF \
      -DLLVM_INCLUDE_DOCS=OFF \
      -DLLVM_ENABLE_OCAMLDOC=OFF \
      -DLLVM_ENABLE_BINDINGS=OFF \
      -DLLVM_OPTIMIZED_TABLEGEN=ON \
      -DLLVM_USE_LINKER=gold \
      -DCMAKE_C_COMPILER="${CC}" \
      -DCMAKE_CXX_COMPILER="${CXX}" \
      -DLIBOMP_TSAN_SUPPORT=1 \
      "${SRC_DIR}/llvm-project/llvm"
      #-DCLANG_OPENMP_NVPTX_DEFAULT_ARCH=sm_61 \
      #-DLIBOMPTARGET_NVPTX_COMPUTE_CAPABILITIES=61 \
      #-DLINK_POLLY_INTO_TOOLS=ON \
      #-DLLVM_BINUTILS_INCDIR="${SRC_DIR}/llvm/tools/binutils/include" \
      #-DLLVM_TARGETS_TO_BUILD="ARM;AArch64;PowerPC;X86" \
      #-DLLVM_VERSION_SUFFIX="-r${LLVM_SVN_REVISION:?}" \
      #-DCLANG_REPOSITORY_STRING="${URL_PREFIX}clang" \
      #-DCLANG_VENDOR="${VENDOR:+"${VENDOR} "}" \
      #-DCLANG_VERSION_SUFFIX="-r${CLANG_SVN_REVISION:?}" \

make install
