#!/bin/bash

# Define target files and directories
TARGET="$HOME/.bash_aliases"
TARGET_DIR="$HOME/.bash_aliases.d"
URL="https://raw.githubusercontent.com/mariugul/bash-aliases/refs/heads/main/.bash_aliases"
LOCAL_FILE="./.bash_aliases"
LOCAL_DIR="./.bash_aliases.d"

# Module files to install
MODULES=("git-core.sh" "git-workflow.sh" "git-aliases.sh" "system.sh")

show_help() {
    echo "Bash Aliases Installer"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script installs modular bash aliases to ~/.bash_aliases and ~/.bash_aliases.d/"
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

install_modules() {
    local dev_mode="$1"
    
    # Create the modules directory
    mkdir -p "$TARGET_DIR"
    
    if [ "$dev_mode" == "--dev" ]; then
        # Copy local modules
        if [ -d "$LOCAL_DIR" ]; then
            for module in "${MODULES[@]}"; do
                if [ -f "$LOCAL_DIR/$module" ]; then
                    cp "$LOCAL_DIR/$module" "$TARGET_DIR/$module"
                    echo " - Installed module: $module"
                fi
            done
        else
            echo "Warning: Local module directory $LOCAL_DIR not found"
        fi
    else
        # Download modules from repository
        for module in "${MODULES[@]}"; do
            local module_url="https://raw.githubusercontent.com/mariugul/bash-aliases/refs/heads/main/.bash_aliases.d/$module"
            curl -sSLo "$TARGET_DIR/$module" "$module_url"
            echo " - Downloaded module: $module"
        done
    fi
}

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
    
    # Install modules
    install_modules "$dev_mode"
}

append_to_existing() {
    if [ "$1" == "--dev" ]; then
        cat "$LOCAL_FILE" >> "$TARGET"
        echo "Appended local aliases to existing .bash_aliases."
    else
        curl -sS "$URL" >> "$TARGET"
        echo "Appended new aliases to existing .bash_aliases."
    fi
    
    # Install modules (will create directory if needed)
    install_modules "$1"
}

download_new() {
    if [ "$1" == "--dev" ]; then
        cp "$LOCAL_FILE" "$TARGET"
        echo "Copied local .bash_aliases."
    else
        curl -sSLo "$TARGET" "$URL"
        echo "Downloaded new .bash_aliases."
    fi
    
    # Install modules
    install_modules "$1"
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
echo -e "\nPlease run 'source ~/.bashrc' to apply changes to your current session."
