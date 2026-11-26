#!/bin/bash
# System Utilities and General Aliases
# Non-git related functions and system shortcuts

# Utility function for adding aliases
alias-add() {
    local name="${1:-}" command="${2:-}"

    if [[ -z "${name}" || -z "${command}" ]]; then
        echo "Usage: alias-add <alias_name> <command>" >&2
        return 1
    fi

    # Bash allows dots/dashes in alias names (e.g. apt-update, g.x); reject
    # everything else (whitespace, shell metacharacters, '=').
    if [[ ! "${name}" =~ ^[a-zA-Z_][a-zA-Z0-9._-]*$ ]]; then
        echo "Invalid alias name '${name}'." >&2
        return 1
    fi

    # Anchored, literal duplicate check — no regex interpretation of the name.
    if awk -v prefix="alias ${name}=" 'index($0, prefix) == 1 { found = 1 } END { exit !found }' \
        ~/.bash_aliases 2>/dev/null; then
        echo "Alias ${name} already exists."
        return 0
    fi

    # Write the command in single quotes, escaping embedded quotes so the
    # file stays valid bash: it's -> 'it'\''s'
    local escaped="${command//\'/\'\\\'\'}"
    printf "alias %s='%s'\n" "${name}" "${escaped}" >> ~/.bash_aliases

    # shellcheck source=/dev/null
    source ~/.bash_aliases
    echo "Alias ${name} added."
}

# Directory navigation aliases
alias c='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# File and editor aliases
alias bash-rc='code ~/.bashrc'
alias bash-aliases='code ~/.bash_aliases'
alias sourcebashrc='source ~/.bashrc && echo "Bash aliases reloaded." && show-help'
alias sourcevenv='source .venv/bin/activate'

# System maintenance aliases
alias apt-update='sudo apt-get update'
alias apt-upgrade='(sudo apt-get update && sudo apt-get upgrade -y)'
alias pipupgrade='pip install --upgrade pip'

# Development tool aliases
alias uvr='uv run'
alias uvi='uv run invoke'

# System information and utilities
alias myip='curl ifconfig.me && echo ""'
alias diskspace='df -h'
alias dirsize='du -sh'

# Utility functions
mkcd() { 
    mkdir -p "${1}" && cd "${1}" || return; 
}

# Repository management
alias open-alias-repo='( xdg-open https://github.com/mariugul/bash-aliases &> /dev/null & )'
alias upgrade-aliases='bash <(curl -sS https://raw.githubusercontent.com/mariugul/bash-aliases/main/install.sh)'
