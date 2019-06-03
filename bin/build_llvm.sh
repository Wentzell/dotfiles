WORK_DIR=$PWD
RELEASE=trunk #branches/release_80 #trunk

cd ${WORK_DIR}
svn co http://llvm.org/svn/llvm-project/llvm/${RELEASE} llvm

cd ${WORK_DIR}
cd llvm/tools
svn co http://llvm.org/svn/llvm-project/cfe/${RELEASE} clang

cd ${WORK_DIR}
cd llvm/tools/clang/tools
svn co http://llvm.org/svn/llvm-project/clang-tools-extra/${RELEASE} extra

#cd ${WORK_DIR}
#cd llvm/tools/clang/tools
#mkdir templight
#git clone https://github.com/mikael-s-persson/templight templight
#echo "add_clang_subdirectory(templight)" >> CMakeLists.txt

#cd ${WORK_DIR}
#cd llvm/tools
#git clone https://github.com/facebookincubator/BOLT llvm-bolt
#cd ..
#patch -p 1 < tools/llvm-bolt/llvm.patch

cd ${WORK_DIR}
cd llvm/tools
svn co http://llvm.org/svn/llvm-project/lld/${RELEASE} lld

cd ${WORK_DIR}
cd llvm/tools
svn co http://llvm.org/svn/llvm-project/polly/${RELEASE} polly

cd ${WORK_DIR}
cd llvm/projects
svn co http://llvm.org/svn/llvm-project/compiler-rt/${RELEASE} compiler-rt

cd ${WORK_DIR}
cd llvm/projects
svn co http://llvm.org/svn/llvm-project/openmp/${RELEASE} openmp

cd ${WORK_DIR}
cd llvm/projects
svn co http://llvm.org/svn/llvm-project/libcxx/${RELEASE} libcxx
svn co http://llvm.org/svn/llvm-project/libcxxabi/${RELEASE} libcxxabi

BUILD_DIR=${WORK_DIR}/llvm_build
INSTALL_DIR=$HOME/opt/llvm_${RELEASE}
TRHEADS=40

mkdir -p ${BUILD_DIR}
cd ${BUILD_DIR}
# Cf. https://llvm.org/docs/CMake.html
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
      -DCMAKE_C_COMPILER="${CC}" \
      -DCMAKE_CXX_COMPILER="${CXX}" \
      -DLIBOMP_TSAN_SUPPORT=1 \
      "${WORK_DIR}/llvm"
      #-DLINK_POLLY_INTO_TOOLS=ON \
      #-DLLVM_BINUTILS_INCDIR="${WORK_DIR}/llvm/tools/binutils/include" \
      #-DLLVM_TARGETS_TO_BUILD="ARM;AArch64;PowerPC;X86" \
      #-DLLVM_VERSION_SUFFIX="-r${LLVM_SVN_REVISION:?}" \
      #-DCLANG_REPOSITORY_STRING="${URL_PREFIX}clang" \
      #-DCLANG_VENDOR="${VENDOR:+"${VENDOR} "}" \
      #-DCLANG_VERSION_SUFFIX="-r${CLANG_SVN_REVISION:?}" \

make install
