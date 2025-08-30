#!/bin/bash

# Define target file
TARGET="$HOME/.bash_aliases"
URL="https://raw.githubusercontent.com/mariugul/bash-aliases/refs/heads/main/.bash_aliases"
LOCAL_FILE="./.bash_aliases"

show_help() {
    echo "Bash Aliases Installer"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script installs bash aliases to ~/.bash_aliases"
    echo ""
    echo "Options:"
    echo "  --dev       Use local .bash_aliases file instead of downloading from repository"
    echo "  --append    Append to existing .bash_aliases file (non-interactive)"
    echo "  --replace   Replace existing .bash_aliases file with backup (non-interactive)"
    echo "  --help      Display this help message and exit"
    echo ""
    echo "If ~/.bash_aliases already exists and no action flag is provided,"
    echo "you will be prompted to either:"
    echo "  - (a)ppend new aliases to the existing file"
    echo "  - (r)eplace the existing file (with backup)"
    echo ""
    echo "Examples:"
    echo "  $0                # Install from repository (interactive)"
    echo "  $0 --dev          # Install from local file (interactive)"
    echo "  $0 --append       # Append from repository (non-interactive)"
    echo "  $0 --replace      # Replace from repository (non-interactive)"
    echo "  $0 --dev --append # Append from local file (non-interactive)"
    echo "  $0 --help         # Show this help"
}

# Parse command line arguments
dev_mode=""
action_mode=""

for arg in "$@"; do
    case $arg in
        --help|-h)
            show_help
            exit 0
            ;;
        --dev)
            dev_mode="--dev"
            ;;
        --append)
            action_mode="append"
            ;;
        --replace)
            action_mode="replace"
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

backup_and_replace() {
    cp "$TARGET" "$TARGET.bak"
    echo " - Backup of existing .bash_aliases created at $TARGET.bak"
    if [ "$dev_mode" == "--dev" ] || [ "$1" == "r" ]; then
        cp "$LOCAL_FILE" "$TARGET"
        echo " - Replaced existing .bash_aliases with the local one."
    else
        curl -sSLo "$TARGET" "$URL"
        echo " - Replaced existing .bash_aliases with the new one."
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

# Handle existing .bash_aliases file
if [ -f "$TARGET" ]; then
    echo -e "\nA .bash_aliases file already exists."
    
    # Non-interactive mode
    if [ -n "$action_mode" ]; then
        case "$action_mode" in
            append)
                append_to_existing "$dev_mode"
                ;;
            replace)
                backup_and_replace "$dev_mode"
                ;;
        esac
    else
        # Interactive mode
        read -p "Do you want to (a)ppend to it or (r)eplace it? " choice
        case "$choice" in
            a|A)
                append_to_existing "$dev_mode"
                ;;
            r|R)
                backup_and_replace "$dev_mode"
                ;;
            *)
                echo "Invalid choice. Exiting."
                exit 1
                ;;
        esac
    fi
else
    download_new "$dev_mode"
fi

echo -e "\nBash aliases installed!"
# Apply changes
source "$HOME/.bashrc"
