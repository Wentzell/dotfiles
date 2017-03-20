#!/bin/bash

# Script fixes parsing of colored compiler output to vim
# Note: 3>&2 2>&1 1>&3 switches stdout and stderr

#make $@ | \
    #sed '/^.*recipe for target.*$/d; /^.*Entering directory/d; /^.*Leaving directory/d' \
    #3>&2 2>&1 1>&3 | \
    #sed 's,\x1b\[01m\x1b\[K/\(.*\)\x1b\[m\x1b\[K,/\1,g; s,\x1b\[K,,g; s,\x1b\[01m,\x1b\[36;1m,g' \
    #3>&2 2>&1 1>&3 \

#make $@ \
    #3>&2 2>&1 1>&3 | \
    #sed 's,\x1b\[01m\x1b\[K/\(.*\)\x1b\[m\x1b\[K,/\1,g; s,\x1b\[K,,g; s,\x1b\[01m,\x1b\[36;1m,g' \
    #3>&2 2>&1 1>&3 \

#{ make $@ 2>&1; } | \
    #sed 's,\x1b\[01m\x1b\[K/\(.*\)\x1b\[m\x1b\[K,/\1,g; s,\x1b\[K,,g; s,\x1b\[01m,\x1b\[36;1m,g'

#make $@ | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g" 2>&1
#( make $@ 2>&1 ) | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g"
#(make $@ 2>&1) | sed "s,t,t,g"
#(make $@ 2>&1) | awk '{gsub("*p*","")}1'

( make $@ 3>&2 2>&1 1>&3- ) | ( sed "s,\x1B\[[0-9;]*[a-zA-Z],,g" 3>&2 2>&1 1>&3- ) | sed "s,\x1B\[[0-9;]*[a-zA-Z],,g"  # WORKING WITH GCC, no colors..

#make $@ 3>&2 2>&1 1>&3 | sed 's,\(.\[0m\)*.\[1m/\(.*\.[h|c]pp\),/\2,g' 3>&2 2>&1 1>&3 # Clang
#make $@ 2>&1 | sed 's,\(.\[0m\)*.\[1m/\(.*\.[h|c]pp\),/\2,g; /^.*recipe for target.*$/d' # .. delay
