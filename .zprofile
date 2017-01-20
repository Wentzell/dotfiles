# ~/.zprofile: executed by the command interpreter for login shells.

addenv () {
    if ! echo $PATH | egrep -q "(^|:)$1/bin($|:)" ; then
	PATH=$1/bin:$PATH
    fi
    if ! echo $CPATH | egrep -q "(^|:)$1/include($|:)" ; then
	CPATH=$1/include:$CPATH
    fi
    if ! echo $LIBRARY_PATH | egrep -q "(^|:)$1/lib($|:)" ; then
	LIBRARY_PATH=$1/lib:$LIBRARY_PATH
    fi
    if ! echo $LD_LIBRARY_PATH | egrep -q "(^|:)$1/lib($|:)" ; then
	LD_LIBRARY_PATH=$1/lib:$LD_LIBRARY_PATH
    fi
}

export VISUAL=vim
export CC=/usr/bin/clang
export CXX=/usr/bin/clang++
export CXXFLAGS=-Wno-c++1z-extensions

if ! echo $PATH | /bin/egrep -q "(^|:)$HOME/bin($|:)" ; then
    export PATH=$HOME/bin:$PATH
fi
