# ~/.zprofile: executed by the command interpreter for login shells.

addlib () {
  if ! echo $CPATH | egrep -q "(^|:)$1/include($|:)" ; then
    export CPATH=$1/include:$CPATH
  fi
  if ! echo $LD_LIBRARY_PATH | egrep -q "(^|:)$1/lib($|:)" ; then
    export LD_LIBRARY_PATH=$1/lib:$1/lib64:$LD_LIBRARY_PATH
  fi
  if ! echo $LIBRARY_PATH | egrep -q "(^|:)$1/lib($|:)" ; then
    export LIBRARY_PATH=$1/lib:$1/lib64:$LIBRARY_PATH
  fi
  if ! echo $PKG_CONFIG_PATH | egrep -q "(^|:)$1/lib($|:)" ; then
    export PKG_CONFIG_PATH=$1/lib/pkgconfig:$PKG_CONFIG_PATH
  fi
}

addpath () {
  if ! echo $PATH | egrep -q "(^|:)$1/bin($|:)" ; then
    export PATH=$1/bin:$PATH
  fi
  if ! echo $MANPATH | egrep -q "(^|:)$1/man($|:)" ; then
    export MANPATH=$1/share/man:$MANPATH
  fi
}

addenv () {
  addlib $1
  addpath $1
}

export VISUAL=vim
export CC=/usr/bin/clang
export CXX=/usr/bin/clang++
export CXXFLAGS=-Wno-c++1z-extensions

if ! echo $PATH | egrep -q "(^|:)$HOME/bin($|:)" ; then
  export PATH=$HOME/bin:$PATH
fi
