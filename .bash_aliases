#!/bin/bash
# Modular Bash Aliases
# Main entry point that sources all alias modules

# Source all modules from ~/.bash_aliases.d/
for module in ~/.bash_aliases.d/*.sh; do
    if [ -r "${module}" ]; then
        # shellcheck source=/dev/null
        source "${module}"
    fi
done


# Helper function to format help entries
_help_entry() {
    local cmd="${1}"
    local desc="${2}"
    local usage="${3}"
    
    printf "%-18s : %s\n" "${cmd}" "$(text "${desc}" italic)"
    if [[ -n "${usage}" ]]; then
        printf "%-18s : %s\n" "" "$(text "${usage}" italic)"
    fi
}

_help_header() {
    text "${1}" blue bold underline italic
}

# Show help for commands
show-help() {
    local main_branch=$(gitmain)
    local current_branch=$(current-branch)

    echo -e "Available Commands:\n"
    _help_header "General Commands"
    _help_entry "c" "Clear the terminal screen"
    _help_entry "..[...]" "Move up one to four directories"
    _help_entry "bash-rc" "Open the .bashrc file in VS Code"
    _help_entry "bash-aliases" "Open the .bash_aliases file in VS Code"
    _help_entry "sourcebashrc" "Apply changes to the .bashrc file"
    _help_entry "sourcevenv" "Activate the Python virtual environment"
    _help_entry "upgrade-aliases" "Upgrade bash aliases (this tool) (use --dev for local version)"
    _help_entry "open-alias-repo" "Open the bash-aliases GitHub repository"
    _help_entry "apt-update" "Update package lists for upgrades"
    _help_entry "apt-upgrade" "Upgrade all packages (update first)"
    _help_entry "pipupgrade" "Upgrade pip to the latest version"
    _help_entry "uvr" "Run Astral (uv run)"
    _help_entry "uvi" "Invoke Astral (uv run invoke)"
    _help_entry "alias-add" "Add a new alias." "Usage: alias-add <alias_name> <command>"
    _help_entry "myip" "Display your public IP address"
    _help_entry "mkcd" "Create and navigate to a new directory"
    _help_entry "diskspace" "Check disk space usage"
    _help_entry "dirsize" "Check the size of a directory"
    echo ""
    _help_header "Git Commands"
    _help_entry "gri" "Start an interactive rebase"
    _help_entry "grm" "Rebase onto the main branch"
    _help_entry "gs" "Show the status of the git repository"
    _help_entry "gl" "Show the git log with stats"
    _help_entry "glo" "Show a decorated, graphical git log"
    _help_entry "glob" "Show a one-line log for the current branch"
    _help_entry "glb" "Show a detailed log for the current branch"
    _help_entry "gb" "List all branches"
    _help_entry "gbd" "Delete a local branch"
    _help_entry "gbo" "Display the current branch name"
    _help_entry "gco" "Checkout a branch"
    _help_entry "gc" "Commit changes with a message"
    _help_entry "gca" "Add all changes and commit with a message"
    _help_entry "gf" "Fetch from the remote repository"
    _help_entry "gfa" "Fetch from all remote repositories"
    _help_entry "current-repo" "Get the name of the current git repository."
    _help_entry "is-git-repo" "Check if the current directory is a git repository."
    _help_entry "current-branch" "Get the name of the current git branch."
    _help_entry "gitmain" "Get the '${main_branch}' branch of the repository."
    _help_entry "commits-on-branch" "Get the number of commits on the current branch."
    _help_entry "gc-release-as" "Create a release commit with a specified version."
    _help_entry "git-first-commit" "Get the first commit of the current branch (${current_branch})."
    _help_entry "prcreate" "Create a pull request with the base branch set to '${main_branch}'" "and the head branch set to the current branch (${current_branch})."
    _help_entry "prcheckout" "Checkout a GitHub pull request by number."
    
    # Show shellcheck commands only if the module is loaded
    if declare -f shellcheck-all >/dev/null 2>&1; then
        echo ""
        _help_header "Shellcheck Commands"
        _help_entry "sc" "Run shellcheck on a single file" "Usage: sc <filename>"
        _help_entry "sca" "Run shellcheck on all bash scripts in project"
        _help_entry "scs" "Run strict shellcheck with all severity levels"
        _help_entry "scf" "Show common shellcheck fixes (manual)"
        _help_entry "sci" "Install shellcheck if not present"
        _help_entry "shellcheck-all" "Detailed shellcheck report for all scripts"
    fi
    echo ""
}

# Startup logic - check git status if in a git repository
if is-git-repo; then
    echo -e "Checked out on \033[01;36m$(current-branch)\033[00m in repo \033[01;36m$(current-repo)\033[00m"
    git_status=$(git status)
    check-and-pull "${git_status}" false
fi
