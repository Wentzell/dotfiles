# ~/.zprofile: executed by the command interpreter for login shells.

addlib () {
  if ! echo $CPLUS_INCLUDE_PATH | egrep -q "(^|:)$1/include($|:)" ; then
    export CPLUS_INCLUDE_PATH=$1/include${CPLUS_INCLUDE_PATH:+:$CPLUS_INCLUDE_PATH}
  fi
  if ! echo $DYLD_LIBRARY_PATH | egrep -q "(^|:)$1/lib($|:)" ; then
    export DYLD_LIBRARY_PATH=$1/lib:$1/lib64${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}
  fi
  if ! echo $LIBRARY_PATH | egrep -q "(^|:)$1/lib($|:)" ; then
    export LIBRARY_PATH=$1/lib${LIBRARY_PATH:+:$LIBRARY_PATH}
    #export LIBRARY_PATH=$1/lib:$1/lib64${LIBRARY_PATH:+:$LIBRARY_PATH}
  fi
  if ! echo $PKG_CONFIG_PATH | egrep -q "(^|:)$1/lib($|:)" ; then
    export PKG_CONFIG_PATH=$1/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}
  fi
}

addpath () {
  if ! echo $PATH | egrep -q "(^|:)$1/bin($|:)" ; then
    export PATH=$1/bin${PATH:+:$PATH}
  fi
  if ! echo $MANPATH | egrep -q "(^|:)$1/man($|:)" ; then
    export MANPATH=:$1/share/man${MANPATH:+:$MANPATH}
  fi
}

addenv () {
  addlib $1
  addpath $1
}


# General Env
export VISUAL=vim
export CTEST_OUTPUT_ON_FAILURE=1
export TRIQS_SHOW_EXCEPTION_TRACE=1
export OMP_NUM_THREADS=1

# My Software
export PYTHONPATH=$HOME/opt:$PYTHONPATH
export PATH=$HOME/bin:$PATH
addenv $HOME/.local
#for f in $HOME/opt/*/; do
  #addenv $f
#done

# Sanitizers
export ASAN_SYMBOLIZER_PATH=$(which llvm-symbolizer)
export ASAN_OPTIONS=symbolize=1:detect_leaks=0 # fast_unwind_on_malloc=0
export UBSAN_SYMBOLIZER_PATH=$(which llvm-symbolizer)
export UBSAN_OPTIONS=symbolize=1:print_stacktrace=1:halt_on_error=1
export TSAN_SYMBOLIZER_PATH=$(which llvm-symbolizer)
export TSAN_OPTIONS=symbolize=1:halt_on_error=1
export MSAN_SYMBOLIZER_PATH=$(which llvm-symbolizer)
export MSAN_OPTIONS=symbolize=1:halt_on_error=1

# Use gnu coreutils over mac commands
export PATH=/usr/local/opt/coreutils/libexec/gnubin:$PATH

# Other software
export MATHJAX_ROOT=$HOME/opt/MathJax

# LLVM/clang
export PATH=/usr/local/opt/llvm/bin:$PATH
export PYTHONPATH=/usr/local/opt/llvm/lib/python2.7/site-packages:$PYTHONPATH

# Python
export LIBRARY_PATH=/usr/local/Cellar/python@2/2.7.15_1/Frameworks/Python.framework/Versions/2.7/lib/python2.7:$LIBRARY_PATH
export CPATH=/usr/local/Cellar/python@2/2.7.15_1/Frameworks/Python.framework/Versions/2.7/include/python2.7:$CPATH
export CPATH=/usr/local/lib/python2.7/site-packages/numpy/core/include:$CPATH
export PYTHONPATH=/Users/nwentzel/opt:$PYTHONPATH
export PYTHONPATH=/Users/nwentzel/Dropbox/Coding/pyed:$PYTHONPATH
export PYTHONPATH=/Users/nwentzel/Dropbox/POE/script/module:$PYTHONPATH

# TRIQS
source /Users/nwentzel/opt/cpp2py/share/cpp2pyvars.sh
source /Users/nwentzel/opt/triqs/share/triqsvars.sh
export TRIQS_SHOW_EXCEPTION_TRACE=1

export FC=gfortran
export CC=clang
export CXX=clang++
export CXXFLAGS='-stdlib=libc++ -Wno-register'
export LDFLAGS="-L${LD_LIBRARY_PATH//:/ -L}"

if ! echo $PATH | egrep -q "(^|:)$HOME/bin($|:)" ; then
  export PATH=$HOME/bin:$PATH
fi
