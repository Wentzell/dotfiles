#!/bin/bash

# Script fixes parsing of colored compiler output to vim
# Order of operations: 
#   Swap stdin and stderr
#   Remove coloring from file names
#   Remove \x1b\[K
#   Swap stdin and stderr

make $@ \
    3>&2 2>&1 1>&3 | \
    sed 's,\x1b\[01m\x1b\[K/\(.*\)\x1b\[m\x1b\[K,/\1,g; s,\x1b\[K,,g' \
    3>&2 2>&1 1>&3
