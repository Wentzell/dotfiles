# ~/.zprofile: executed by the command interpreter for login shells.

export VISUAL=vim

if ! echo $PATH | /bin/egrep -q "(^|:)$HOME/bin($|:)" ; then
    export PATH=$HOME/bin:$PATH
fi
