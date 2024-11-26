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
export DOCKER_DEFAULT_PLATFORM=linux/amd64
export BREW_PREFIX=$(brew --prefix)

# === My Software
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
export PATH=$BREW_PREFIX/opt/coreutils/libexec/gnubin:$PATH

# Other software
export MATHJAX_ROOT=$HOME/opt/MathJax

# Homebrew
export PATH=$BREW_PREFIX/bin:$PATH

# LLVM/clang
export PATH=$BREW_PREFIX/opt/llvm/bin:$PATH
export PYTHONPATH=$BREW_PREFIX/opt/llvm/lib/python3.13/site-packages:$PYTHONPATH

# Python
export PYTHONPATH=$HOME/opt/myvenv/lib/python3.13/site-packages:$PYTHONPATH
export PATH=$HOME/opt/myvenv/bin:$PATH
export VIRTUAL_ENV=$HOME/opt/myvenv

# TRIQS
source $HOME/opt/triqs/share/triqs/triqsvars.sh
export TRIQS_SHOW_EXCEPTION_TRACE=1

export FC=gfortran
export CC=clang
export CXX=clang++
export CXXFLAGS='-stdlib=libc++ -Wno-register'
#export LDFLAGS="-L${LD_LIBRARY_PATH//:/ -L}"

if ! echo $PATH | egrep -q "(^|:)$HOME/bin($|:)" ; then
  export PATH=$HOME/bin:$PATH
fi
