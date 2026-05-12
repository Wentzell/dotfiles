#!/bin/bash
cd $(dirname $0)

# Function that links a file to $HOME, DELETING it there if it exists already

function linkFile() {
    LINK_TO_NAME=$2
    if [ -z $LINK_TO_NAME ]; then
        LINK_TO_NAME=$1
    fi
#    if [ -a $HOME/$LINK_TO_NAME ]; then
        #echo "**** Found existing $LINK_TO_NAME, skipping..."
        echo "**** Found existing $LINK_TO_NAME, deleting..."
        rm -rf $HOME/$LINK_TO_NAME
        echo "Linking $1 to $LINK_TO_NAME"
        ln -s $PWD/$1 $HOME/$LINK_TO_NAME
#    elif [ -h $HOME/$LINK_TO_NAME ]; then
#        echo "Already symlinked $LINK_TO_NAME, skipping..."
#    else
#        echo "Linking $1 to $LINK_TO_NAME"
#        ln -s $PWD/$1 $HOME/$LINK_TO_NAME
#    fi
}

# Link files to home and exclude the ones containing certain strings

for F in $(ls -a1 | \
    grep -v '.git$' | \
    grep -v disabled | \
    grep -v .gitmodules | \
    grep -v .gitignore | \
    grep -v .dropbox | \
    grep -v .bashrc | \
    grep -v .config | \
    grep -v .codex | \
    grep -v .claude | \
    grep -v setup.sh | \
    grep -v link.sh | \
    grep -v Desktop | \
    grep -v pkglst | \
    grep -v aurlst | \
    grep -v piplst | \
    grep -v brewlst | \
    egrep -v "^..?$" | \
    egrep -v "^.*un~$" | \
    grep -v .DS_Store \
    ); do linkFile $F
done

mkdir -p $HOME/.config
ln -s $PWD/.config/nvim $HOME/.config/nvim

# .claude: symlink individual tracked entries (preserves runtime state)
mkdir -p $HOME/.claude
for F in CLAUDE.md settings.json statusline.sh commands hooks; do
    rm -rf $HOME/.claude/$F
    ln -s $PWD/.claude/$F $HOME/.claude/$F
done

# .codex: symlink individual entries (preserves runtime state files like auth.json, sessions/, history.jsonl)
mkdir -p $HOME/.codex
for F in config.toml AGENTS.md prompts; do
    rm -rf $HOME/.codex/$F
    ln -s $PWD/.codex/$F $HOME/.codex/$F
done
