#!/bin/bash
# System Utilities and General Aliases
# Non-git related functions and system shortcuts

# Utility function for adding aliases
alias-add() {
    if ! grep -q "alias $1=" ~/.bash_aliases; then
        echo "alias $1='$2'" >> ~/.bash_aliases
        source ~/.bash_aliases
    else
        echo "Alias $1 already exists."
        return 0
    fi
    source ~/.bash_aliases
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
    mkdir -p "$1" && cd "$1"; 
}

# Repository management
alias open-alias-repo='( xdg-open https://github.com/mariugul/bash-aliases &> /dev/null & )'
alias upgrade-aliases='bash <(curl -sS https://raw.githubusercontent.com/mariugul/bash-aliases/main/install.sh)'
