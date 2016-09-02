#!/usr/bin/env sh
cd $(dirname $0)

function linkFile() {
    LINK_TO_NAME=$2
    if [ -z $LINK_TO_NAME ]; then
        LINK_TO_NAME=$1
    fi
    if [ -a $HOME/$LINK_TO_NAME ]; then
        #echo "**** Found existing $LINK_TO_NAME, skipping..."
        echo "**** Found existing $LINK_TO_NAME, deleting..."
        rm -rf $HOME/$LINK_TO_NAME
        echo "Linking $1 to $LINK_TO_NAME"
        ln -s $PWD/$1 $HOME/$LINK_TO_NAME
    elif [ -h $HOME/$LINK_TO_NAME ]; then
        echo "Already symlinked $LINK_TO_NAME, skipping..."
    else
        echo "Linking $1 to $LINK_TO_NAME"
        ln -s $PWD/$1 $HOME/$LINK_TO_NAME
    fi
}

for F in $(ls -a1 | \
    grep -v '.git$' | \
    grep -v disabled | \
    grep -v .ssh_config | \
    grep -v .gitmodules | \
    grep -v .gitignore | \
    grep -v .dropbox | \
    grep -v .bashrc | \
    grep -v setup.sh | \
    grep -v link.sh | \
    grep -v Desktop | \
    egrep -v "^..?$" | \
    egrep -v "^.*un~$" | \
    grep -v .DS_Store \
    ); do linkFile $F
done

#export HOSTNAME=$(hostname)

#if [ -d "Desktop-$HOSTNAME" ]; then
    #linkFile "Desktop-$HOSTNAME" "Desktop"
#else 
    #echo "Unable to find Desktop-$HOSTNAME to link to Desktop"
#fi
