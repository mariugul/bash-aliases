#!/bin/bash

set -e

# Define target files and directories
TARGET="${HOME}/.bash_aliases"
TARGET_DIR="${HOME}/.bash_aliases.d"
URL="https://raw.githubusercontent.com/mariugul/bash-aliases/refs/heads/main/.bash_aliases"

# Anchor --dev paths to this script's directory so it works from any CWD
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_FILE="${SCRIPT_DIR}/.bash_aliases"
LOCAL_DIR="${SCRIPT_DIR}/.bash_aliases.d"
LOCAL_SHELLCHECKRC="${SCRIPT_DIR}/.shellcheckrc"

# Profile files checked for the .bash_aliases source block, in preference
# order. The first existing file wins; ~/.bashrc is created if none exist.
PROFILE_CANDIDATES=("${HOME}/.bashrc" "${HOME}/.bash_profile" "${HOME}/.bash_login" "${HOME}/.profile")

# curl flags: fail on HTTP errors, retry transient failures
CURL=(curl -fsSL --retry 2)

# Base module files to install
BASE_MODULES=("git-core.sh" "git-workflow.sh" "git-aliases.sh" "system.sh" "text.sh")

# Get modules list based on dev mode
get_modules() {
    local dev_mode="${1}"
    local modules=("${BASE_MODULES[@]}")
    
    # Only include shellcheck.sh in dev mode
    if [[ "${dev_mode}" == "--dev" ]]; then
        modules+=("shellcheck.sh")
    fi
    
    printf '%s\n' "${modules[@]}"
}

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

for arg in "${@}"; do
    case ${arg} in
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
            echo "Unknown option: ${arg}"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
done

# Ensure the user's shell profile sources ~/.bash_aliases — without this
# the install is silently inert on any setup whose profile doesn't already
# source it (non-Ubuntu distros, custom dotfiles, headless logins).
ensure_profile() {
    local profile_file=""
    for candidate in "${PROFILE_CANDIDATES[@]}"; do
        if [ -f "${candidate}" ]; then
            profile_file="${candidate}"
            break
        fi
    done

    if [ -z "${profile_file}" ]; then
        profile_file="${PROFILE_CANDIDATES[0]}"
        echo "Creating ${profile_file}..."
        touch "${profile_file}"
    fi

    if ! grep -q "source.*\.bash_aliases" "${profile_file}" 2>/dev/null; then
        {
            echo ""
            echo "# Source bash aliases"
            echo "if [ -f ~/.bash_aliases ]; then"
            echo "    source ~/.bash_aliases"
            echo "fi"
        } >> "${profile_file}"
        echo " - Added .bash_aliases source to ${profile_file}"
    fi
}

install_modules() {
    local dev_mode="${1}"
    
    # Get the appropriate modules list
    local modules
    readarray -t modules < <(get_modules "${dev_mode}")
    
    # Create the modules directory
    mkdir -p "${TARGET_DIR}"
    
    if [ "${dev_mode}" == "--dev" ]; then
        # Copy local modules
        if [ -d "${LOCAL_DIR}" ]; then
            for module in "${modules[@]}"; do
                if [ -f "${LOCAL_DIR}/${module}" ]; then
                    cp "${LOCAL_DIR}/${module}" "${TARGET_DIR}/${module}"
                    echo " - Installed module: ${module}"
                fi
            done
        else
            echo "Warning: Local module directory ${LOCAL_DIR} not found"
        fi
        
        # Copy shellcheck configuration if it exists locally (only in dev mode)
        if [ -f "${LOCAL_SHELLCHECKRC}" ]; then
            cp "${LOCAL_SHELLCHECKRC}" "${HOME}/.shellcheckrc"
            echo " - Installed .shellcheckrc configuration"
        fi
    else
        # Download modules from repository
        for module in "${modules[@]}"; do
            local module_url="https://raw.githubusercontent.com/mariugul/bash-aliases/refs/heads/main/.bash_aliases.d/${module}"
            "${CURL[@]}" -o "${TARGET_DIR}/${module}" "${module_url}"
            echo " - Downloaded module: ${module}"
        done
        
        # Note: shellcheck.sh and .shellcheckrc are not downloaded in regular installs
        echo " - Skipped shellcheck module (use --dev for development tools)"
    fi
}

backup_and_replace() {
    cp "${TARGET}" "${TARGET}.bak"
    echo " - Backup of existing .bash_aliases created at ${TARGET}.bak"
    if [ "${dev_mode}" == "--dev" ]; then
        cp "${LOCAL_FILE}" "${TARGET}"
        echo " - Replaced existing .bash_aliases with the local one."
    else
        "${CURL[@]}" -o "${TARGET}" "${URL}"
        echo " - Replaced existing .bash_aliases with the new one."
    fi
    
    # Install modules
    install_modules "${dev_mode}"
}

append_to_existing() {
    if [ "${1}" == "--dev" ]; then
        cat "${LOCAL_FILE}" >> "${TARGET}"
        echo "Appended local aliases to existing .bash_aliases."
    else
        "${CURL[@]}" "${URL}" >> "${TARGET}"
        echo "Appended new aliases to existing .bash_aliases."
    fi
    
    # Install modules (will create directory if needed)
    install_modules "${1}"
}

download_new() {
    if [ "${1}" == "--dev" ]; then
        cp "${LOCAL_FILE}" "${TARGET}"
        echo "Copied local .bash_aliases."
    else
        "${CURL[@]}" -o "${TARGET}" "${URL}"
        echo "Downloaded new .bash_aliases."
    fi
    
    # Install modules
    install_modules "${1}"
}

echo "Installing bash aliases..."

# Handle existing .bash_aliases file
if [ -f "${TARGET}" ]; then
    echo -e "\nA .bash_aliases file already exists."
    
    # Non-interactive mode
    if [ -n "${action_mode}" ]; then
        case "${action_mode}" in
            append)
                append_to_existing "${dev_mode}"
                ;;
            replace)
                backup_and_replace "${dev_mode}"
                ;;
        esac
    else
        # Interactive mode
        read -r -p "Do you want to (a)ppend to it or (r)eplace it? " choice || true
        case "${choice}" in
            a|A)
                append_to_existing "${dev_mode}"
                ;;
            r|R)
                backup_and_replace "${dev_mode}"
                ;;
            *)
                echo "Invalid choice. Exiting."
                exit 1
                ;;
        esac
    fi
else
    download_new "${dev_mode}"
fi

# Wire .bash_aliases into the user's profile (no-op if already sourced)
ensure_profile

echo -e "\nBash aliases installed!"
echo -e "\nPlease run 'source' on your shell profile (e.g. 'source ~/.bashrc') or open a new shell to apply changes."
