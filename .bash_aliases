#!/bin/bash
# Modular Bash Aliases
# Main entry point that sources all alias modules

# Source all modules from ~/.bash_aliases.d/
for module in ~/.bash_aliases.d/*.sh; do
    if [ -r "$module" ]; then
        source "$module"
    fi
done

# Startup logic - check git status if in a git repository
if is-git-repo; then
    echo -e "Checked out on \033[01;36m$(current-branch)\033[00m in repo \033[01;36m$(current-repo)\033[00m"
    git_status=$(git status)
    check-and-pull "$git_status" false
fi
