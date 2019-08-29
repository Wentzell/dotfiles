WORK_DIR=$PWD
RELEASE=llvmorg-8.0.1

# Cf. https://llvm.org/docs/GettingStarted.html
cd ${WORK_DIR}
git clone https://github.com/llvm/llvm-project --branch $RELEASE --depth 1

#cd ${WORK_DIR}
#cd llvm-project/llvm/tools/clang/tools
#mkdir templight
#git clone https://github.com/mikael-s-persson/templight templight
#echo "add_clang_subdirectory(templight)" >> CMakeLists.txt

#cd ${WORK_DIR}
#cd llvm-project/llvm/tools
#git clone https://github.com/facebookincubator/BOLT llvm-bolt
#cd ..
#patch -p 1 < tools/llvm-bolt/llvm.patch

BUILD_DIR=${WORK_DIR}/llvm_build
INSTALL_DIR=$HOME/opt/llvm_8.0.1
TRHEADS=40

mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}
# Cf. https://llvm.org/docs/CMake.html
cmake -DCMAKE_BUILD_TYPE=Release \
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
      "${WORK_DIR}/llvm-project/llvm"
      #-DLINK_POLLY_INTO_TOOLS=ON \
      #-DLLVM_BINUTILS_INCDIR="${WORK_DIR}/llvm/tools/binutils/include" \
      #-DLLVM_TARGETS_TO_BUILD="ARM;AArch64;PowerPC;X86" \
      #-DLLVM_VERSION_SUFFIX="-r${LLVM_SVN_REVISION:?}" \
      #-DCLANG_REPOSITORY_STRING="${URL_PREFIX}clang" \
      #-DCLANG_VENDOR="${VENDOR:+"${VENDOR} "}" \
      #-DCLANG_VERSION_SUFFIX="-r${CLANG_SVN_REVISION:?}" \

make install
