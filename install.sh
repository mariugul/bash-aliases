#!/bin/bash

# Define target file
TARGET="$HOME/.bash_aliases"
URL="https://raw.githubusercontent.com/mariugul/bash-aliases/refs/heads/main/.bash_alisaes"

backup_and_replace() {
    cp "$TARGET" "$TARGET.bak"
    echo "Backup of existing .bash_aliases created at $TARGET.bak"
    curl -sSLo "$TARGET" "$URL"
    echo "Replaced existing .bash_aliases with the new one."
}

append_to_existing() {
    curl -sS "$URL" >> "$TARGET"
    echo "Appended new aliases to existing .bash_aliases."
}

download_new() {
    curl -sSLo "$TARGET" "$URL"
    echo "Downloaded new .bash_aliases."
}

# Backup existing .bash_aliases if it exists
if [ -f "$TARGET" ]; then
    echo "A .bash_aliases file already exists."
    read -p "Do you want to (a)ppend to it or (r)eplace it? " choice
    case "$choice" in
        a|A)
            append_to_existing
            ;;
        r|R)
            backup_and_replace
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
else
    download_new
fi


echo "Bash aliases installed!"
# Apply changes
source "$TARGET"