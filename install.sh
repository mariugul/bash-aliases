#!/bin/bash

# Define target file
TARGET="$HOME/.bash_aliases"
URL="https://raw.githubusercontent.com/mariugul/bash-aliases/refs/heads/main/.bash_aliases"
LOCAL_FILE="./.bash_aliases"
# add input for local file
dev_mode=$1
echo $dev_mode

backup_and_replace() {
    cp "$TARGET" "$TARGET.bak"
    echo "Backup of existing .bash_aliases created at $TARGET.bak"
    if [ "$dev_mode" == "--dev" ] || [ "$1" == "r" ]; then
        cp "$LOCAL_FILE" "$TARGET"
        echo "Replaced existing .bash_aliases with the local one."
    else
        curl -sSLo "$TARGET" "$URL"
        echo "Replaced existing .bash_aliases with the new one."
    fi
}

append_to_existing() {
    if [ "$1" == "--dev" ]; then
        cat "$LOCAL_FILE" >> "$TARGET"
        echo "Appended local aliases to existing .bash_aliases."
    else
        curl -sS "$URL" >> "$TARGET"
        echo "Appended new aliases to existing .bash_aliases."
    fi
}

download_new() {
    if [ "$1" == "--dev" ]; then
        cp "$LOCAL_FILE" "$TARGET"
        echo "Copied local .bash_aliases."
    else
        curl -sSLo "$TARGET" "$URL"
        echo "Downloaded new .bash_aliases."
    fi
}

echo "Installing bash aliases..."

# Backup existing .bash_aliases if it exists
if [ -f "$TARGET" ]; then
    echo "A .bash_aliases file already exists."
    read -p "Do you want to (a)ppend to it or (r)eplace it? " choice
    case "$choice" in
        a|A)
            append_to_existing "$1"
            ;;
        r|R)
            backup_and_replace "$1"
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
else
    download_new "$1"
fi

echo "Bash aliases installed!"
# Apply changes
source "$HOME/.bashrc"
