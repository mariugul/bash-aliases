#!/bin/bash

# Windows Git Bash Installer for Bash Aliases
# This script installs bash aliases for Git Bash on Windows

set -e

# Define target files and directories
TARGET="${HOME}/.bash_aliases"
TARGET_DIR="${HOME}/.bash_aliases.d"
URL="https://raw.githubusercontent.com/mariugul/bash-aliases/refs/heads/main/.bash_aliases"
MODULES_URL="https://raw.githubusercontent.com/mariugul/bash-aliases/refs/heads/main/.bash_aliases.d"

# Base module files to install
BASE_MODULES=("git-core.sh" "git-workflow.sh" "git-aliases.sh" "system.sh" "text.sh")

# Git Bash profile file
BASH_PROFILE="${HOME}/.bash_profile"

show_help() {
    echo "Bash Aliases Installer for Windows (Git Bash)"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script installs modular bash aliases for Git Bash on Windows"
    echo "to ~/.bash_aliases and ~/.bash_aliases.d/"
    echo ""
    echo "Options:"
    echo "  --append    Append to existing .bash_aliases file (non-interactive)"
    echo "  --replace   Replace existing .bash_aliases file with backup (non-interactive)"
    echo "  --help, -h  Display this help message and exit"
    echo ""
    echo "If ~/.bash_aliases already exists and no action flag is provided,"
    echo "you will be prompted to either:"
    echo "  - (a)ppend new aliases to the existing file"
    echo "  - (r)eplace the existing file (with backup)"
    echo ""
    echo "Examples:"
    echo "  $0                # Install (interactive)"
    echo "  $0 --append       # Append (non-interactive)"
    echo "  $0 --replace      # Replace with backup (non-interactive)"
    echo "  $0 --help         # Show this help"
}

# Parse command line arguments
action_mode=""

for arg in "${@}"; do
    case ${arg} in
        --help|-h)
            show_help
            exit 0
            ;;
        --append)
            action_mode="append"
            ;;
        --replace)
            action_mode="replace"
            ;;
        *)
            echo "Unknown option: ${arg}"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# Ensure .bash_profile sources .bash_aliases
ensure_bash_profile() {
    if [ ! -f "${BASH_PROFILE}" ]; then
        echo "Creating ${BASH_PROFILE}..."
        touch "${BASH_PROFILE}"
    fi

    # Check if .bash_aliases is already sourced
    if ! grep -q "source.*\.bash_aliases" "${BASH_PROFILE}" 2>/dev/null; then
        echo "" >> "${BASH_PROFILE}"
        echo "# Source bash aliases" >> "${BASH_PROFILE}"
        echo "if [ -f ~/.bash_aliases ]; then" >> "${BASH_PROFILE}"
        echo "    source ~/.bash_aliases" >> "${BASH_PROFILE}"
        echo "fi" >> "${BASH_PROFILE}"
        echo "Added .bash_aliases source to ${BASH_PROFILE}"
    fi
}

# Download a file with curl
download_file() {
    local url="$1"
    local output="$2"
    curl -sSLo "${output}" "${url}"
}

install_modules() {
    # Create the modules directory
    mkdir -p "${TARGET_DIR}"

    # Download modules from repository
    for module in "${BASE_MODULES[@]}"; do
        local module_url="${MODULES_URL}/${module}"
        download_file "${module_url}" "${TARGET_DIR}/${module}"
        echo " - Downloaded module: ${module}"
    done
}

backup_and_replace() {
    cp "${TARGET}" "${TARGET}.bak"
    echo " - Backup of existing .bash_aliases created at ${TARGET}.bak"
    download_file "${URL}" "${TARGET}"
    echo " - Replaced existing .bash_aliases with the new one."

    # Install modules
    install_modules
}

append_to_existing() {
    curl -sS "${URL}" >> "${TARGET}"
    echo "Appended new aliases to existing .bash_aliases."

    # Install modules (will create directory if needed)
    install_modules
}

download_new() {
    download_file "${URL}" "${TARGET}"
    echo "Downloaded new .bash_aliases."

    # Install modules
    install_modules
}

echo "Installing bash aliases for Windows (Git Bash)..."

# Ensure .bash_profile is set up
ensure_bash_profile

# Handle existing .bash_aliases file
if [ -f "${TARGET}" ]; then
    echo -e "\nA .bash_aliases file already exists."

    # Non-interactive mode
    if [ -n "${action_mode}" ]; then
        case "${action_mode}" in
            append)
                append_to_existing
                ;;
            replace)
                backup_and_replace
                ;;
        esac
    else
        # Interactive mode
        read -r -p "Do you want to (a)ppend to it or (r)eplace it? " choice
        case "${choice}" in
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
    fi
else
    download_new
fi

echo -e "\nBash aliases installed!"
echo -e "\nPlease run one of the following to apply changes:"
echo "  source ~/.bash_profile"
echo "  source ~/.bash_aliases"
echo "Or restart your Git Bash terminal."
