WORK_DIR=$PWD
mkdir -p ${WORK_DIR}

cd ${WORK_DIR}
svn co http://llvm.org/svn/llvm-project/llvm/trunk llvm

cd ${WORK_DIR}
cd llvm/tools
svn co http://llvm.org/svn/llvm-project/cfe/trunk clang

cd ${WORK_DIR}
cd llvm/tools/clang/tools
svn co http://llvm.org/svn/llvm-project/clang-tools-extra/trunk extra

cd ${WORK_DIR}
cd llvm/tools/clang/tools
mkdir templight
git clone https://github.com/mikael-s-persson/templight templight
echo "add_clang_subdirectory(templight)" >> CMakeLists.txt

cd ${WORK_DIR}
cd llvm/tools
git clone https://github.com/facebookincubator/BOLT llvm-bolt
cd ..
patch -p 1 < tools/llvm-bolt/llvm.patch

cd ${WORK_DIR}
cd llvm/tools
svn co http://llvm.org/svn/llvm-project/lld/trunk lld

cd ${WORK_DIR}
cd llvm/tools
svn co http://llvm.org/svn/llvm-project/polly/trunk polly

cd ${WORK_DIR}
cd llvm/projects
svn co http://llvm.org/svn/llvm-project/compiler-rt/trunk compiler-rt

cd ${WORK_DIR}
cd llvm/projects
svn co http://llvm.org/svn/llvm-project/openmp/trunk openmp

cd ${WORK_DIR}
cd llvm/projects
svn co http://llvm.org/svn/llvm-project/libcxx/trunk libcxx
svn co http://llvm.org/svn/llvm-project/libcxxabi/trunk libcxxabi

BUILD_DIR=$PWD/llvm_build
INSTALL_DIR=$HOME/opt/llvm
TRHEADS=40

mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}
cmake -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_C_FLAGS="-O3 -march=native" \
      -DCMAKE_CXX_FLAGS="-O3 -march=native" \
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
      "${WORK_DIR}/llvm"
      #-DLINK_POLLY_INTO_TOOLS=ON \
      #-DCMAKE_C_COMPILER="${CC}" \
      #-DCMAKE_CXX_COMPILER="${CXX}" \
      #-DLLVM_BINUTILS_INCDIR="${WORK_DIR}/llvm/tools/binutils/include" \
      #-DLLVM_TARGETS_TO_BUILD="ARM;AArch64;PowerPC;X86" \
      #-DLLVM_VERSION_SUFFIX="-r${LLVM_SVN_REVISION:?}" \
      #-DCLANG_REPOSITORY_STRING="${URL_PREFIX}clang" \
      #-DCLANG_VENDOR="${VENDOR:+"${VENDOR} "}" \
      #-DCLANG_VERSION_SUFFIX="-r${CLANG_SVN_REVISION:?}" \

make -j ${THREADS} install
