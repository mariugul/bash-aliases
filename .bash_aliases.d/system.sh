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

# Show help for commands
show-help() {
    local main_branch=$(gitmain)
    local current_branch=$(current-branch)

    echo "Available Commands:"
    echo ""
    echo "General Commands:"
    echo "  c               : Clear the terminal screen"
    echo "  ..              : Move up one directory"
    echo "  ...             : Move up two directories"
    echo "  ....            : Move up three directories"
    echo "  .....           : Move up four directories"
    echo "  bash-rc         : Open the .bashrc file in VS Code"
    echo "  bash-aliases    : Open the .bash_aliases file in VS Code"
    echo "  sourcebashrc    : Apply changes to the .bashrc file"
    echo "  sourcevenv      : Activate the Python virtual environment"
    echo "  upgrade-aliases : Upgrade bash aliases (this tool) (use --dev for local version)"
    echo "  open-alias-repo : Open the bash-aliases GitHub repository"
    echo "  apt-update      : Update package lists for upgrades"
    echo "  apt-upgrade     : Upgrade all packages (update first)"
    echo "  pipupgrade      : Upgrade pip to the latest version"
    echo "  uvr             : Run Astral (uv run)"
    echo "  uvi             : Invoke Astral (uv run invoke)"
    echo "  alias-add       : Add a new alias."
    echo "                    Usage: alias-add <alias_name> <command>"
    echo "  myip            : Display your public IP address"
    echo "  mkcd            : Create and navigate to a new directory"
    echo "  diskspace       : Check disk space usage"
    echo "  dirsize         : Check the size of a directory"
    echo ""
    echo "Git Commands:"
    echo "  gri             : Start an interactive rebase"
    echo "  grm             : Rebase onto the main branch"
    echo "  gs              : Show the status of the git repository"
    echo "  gl              : Show the git log with stats"
    echo "  glo             : Show a decorated, graphical git log"
    echo "  glob            : Show a one-line log for the current branch"
    echo "  glb             : Show a detailed log for the current branch"
    echo "  gb              : List all branches"
    echo "  gbd             : Delete a local branch"
    echo "  gbo             : Display the current branch name"
    echo "  gco             : Checkout a branch"
    echo "  gc              : Commit changes with a message"
    echo "  gca             : Add all changes and commit with a message"
    echo "  gf              : Fetch from the remote repository"
    echo "  gfa             : Fetch from all remote repositories"
    echo "  current-repo    : Get the name of the current git repository."
    echo "  is-git-repo     : Check if the current directory is a git repository."
    echo "  current-branch  : Get the name of the current git branch."
    echo "  gitmain         : Get the '$main_branch' branch of the repository."
    echo "  commits-on-branch : Get the number of commits on the current branch."
    echo "  gc-release-as   : Create a release commit with a specified version."
    echo "  git-first-commit: Get the first commit of the current branch."
    echo "  prcreate        : Create a pull request with the base branch set to '$main_branch' and the head branch set to the current branch."
    echo "  prcheckout      : Checkout a GitHub pull request by number."
    echo ""
}
