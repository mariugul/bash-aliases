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

# Degrade gracefully on partial/legacy installs: if text.sh isn't present
# provide a plain-text fallback so show-help and friends still work.
if ! declare -f text >/dev/null 2>&1; then
    text() { echo "${1:-}"; }
fi

# Warn once if the core modules are missing entirely (e.g. only
# ~/.bash_aliases was installed) instead of dying with 'command not found'.
if ! declare -f is-git-repo >/dev/null 2>&1; then
    echo "bash-aliases: modules not found in ~/.bash_aliases.d — re-run the installer to fix." >&2
fi


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
    local main_branch current_branch
    main_branch=$(gitmain 2>/dev/null)
    current_branch=$(current-branch 2>/dev/null)

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
    _help_entry "gls" "Show git stats for commits on current branch" "Usage: gls (concise) or gls -v (verbose)"
    _help_entry "glo" "Show a decorated, graphical git log"
    _help_entry "glob" "Show a one-line log for the current branch"
    _help_entry "glb" "Show a detailed log for the current branch"
    _help_entry "glr" "Show commit messages between two commits/branches" "Usage: glr <from> <to>"
    _help_entry "glm" "Show full commit messages between two points" "Usage: glm <from> <to>"
    _help_entry "gb" "List all branches"
    _help_entry "gbd" "Delete local branches (interactive, multi-select)"
    _help_entry "gitcleanup" "Delete branches with gone upstreams and their linked worktrees" "Usage: gitcleanup [--dry-run] [--yes]"
    _help_entry "gbo" "Display the current branch name"
    _help_entry "gco" "Checkout a branch"
    _help_entry "gc" "Commit changes with a message"
    _help_entry "gca" "Add all changes and commit with a message"
    _help_entry "gcempty" "Create an empty commit to trigger CI"
    _help_entry "gcnoverify" "Commit without running hooks"
    _help_entry "gf" "Fetch from the remote repository"
    _help_entry "gfa" "Fetch from all remote repositories"
    _help_entry "gfo" "Fetch the main branch from the primary remote"
    _help_entry "gps" "Push to the remote (auto-sets upstream if needed)"
    _help_entry "gpsupstream" "Push and set the upstream branch"
    _help_entry "gpu" "Pull from the remote repository"
    _help_entry "gpur" "Pull with rebase"
    _help_entry "gpf" "Push with force"
    _help_entry "gss" "Stash changes"
    _help_entry "gconfig" "Edit the global git config"
    _help_entry "gsw" "Switch branches" "Usage: gsw (interactive picker) or gsw <branch>"
    _help_entry "gswc" "Create and switch to a new branch"
    _help_entry "gswm" "Switch to the main branch"
    _help_entry "gsw-" "Switch to the previous branch"
    _help_entry "gitundolast" "Undo the last commit, keeping changes staged"
    _help_entry "sync-fork" "Sync a forked repo with upstream"
    _help_entry "current-repo" "Get the name of the current git repository."
    _help_entry "is-git-repo" "Check if the current directory is a git repository."
    _help_entry "current-branch" "Get the name of the current git branch."
    _help_entry "gitmain" "Get the '${main_branch}' branch of the repository."
    _help_entry "commits-on-branch" "Get the number of commits on the current branch."
    _help_entry "gc-release-as" "Create a release commit with a specified version."
    _help_entry "git-first-commit" "Get the first commit of the current branch (${current_branch})."
    _help_entry "prcreate" "Create a pull request with the base branch set to '${main_branch}'" "and the head branch set to the current branch (${current_branch}). Uses gh for GitHub remotes, fj for Forgejo."
    _help_entry "prcheckout" "Checkout a pull request by number."
    _help_entry "prview" "Open the current branch's pull request in the browser."

    # Show maintenance commands only if the module is loaded
    if declare -f docker-clean >/dev/null 2>&1; then
        echo ""
        _help_header "Maintenance Commands"
        _help_entry "disk-top" "Show the largest files/directories under a path" "Usage: disk-top [path] [count]"
        _help_entry "docker-clean" "Reclaim docker space (dry run; --yes prunes)"
        _help_entry "apt-clean" "Autoremove packages and clear apt cache (dry run; --yes executes)"
        _help_entry "journal-clean" "Vacuum systemd journal logs (dry run; --yes [size] executes)"
        _help_entry "ports" "Show listening TCP/UDP ports"
    fi

    echo ""
    _help_header "Text Formatting"
    _help_entry "text" "Style text with colors and formats" "Usage: text <string> [color] [bold,italic,underline]"
    _help_entry "bold" "Print bold text"
    _help_entry "italic" "Print italic text"
    _help_entry "underline" "Print underlined text"

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
if declare -f is-git-repo >/dev/null 2>&1 && is-git-repo; then
    echo -e "Checked out on \033[01;36m$(current-branch)\033[00m in repo \033[01;36m$(current-repo)\033[00m"
    # check-and-pull queries git directly; no need to run a full `git status`
    # (which is expensive in large repos) on every shell start.
    if declare -f check-and-pull >/dev/null 2>&1; then
        check-and-pull "" false
    fi
fi
