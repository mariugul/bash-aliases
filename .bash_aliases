# Methods

current_repo() {
    git remote get-url origin 2> /dev/null | sed -n 's#.*/\([^.]*\)\.git#\1#p'
}

is_git_repo() {
    git rev-parse --is-inside-work-tree > /dev/null 2>&1
}

check_git_repo() {
    if ! is_git_repo; then
        echo "Not a git repository."
        return 1
    fi
}

alias_add() {
    if ! grep -q "alias $1=" ~/.bash_aliases; then
        echo "alias $1='$2'" >> ~/.bash_aliases
        source ~/.bash_aliases
    else
        echo "Alias $1 already exists."
    fi
    source ~/.bash_aliases
}

current_branch() {
    git branch --show-current
}

is_upstream_branch() {
    check_git_repo || return 1

    local current_branch=$(current_branch)
    local upstream_branch=$(git rev-parse --abbrev-ref "$current_branch"@{upstream} 2> /dev/null)

    if [ -z "$upstream_branch" ]; then
        echo "The branch '$current_branch' is not tracking any upstream branch."
        read -p "Do you want to set the upstream branch now? [y/N] " set_upstream
        if [[ "$set_upstream" =~ ^[Yy]$ ]]; then
            gpsupstream
        else
            echo "Skipped setting upstream branch."
        fi
        return 1
    else
        echo "The branch '$current_branch' is tracking the upstream branch '$upstream_branch'."
        return 0
    fi
}

declare -A MAIN_BRANCHES

gitmain() {
    check_git_repo || return 1

    local repo=$(current_repo)
    if [ -z "$repo" ]; then
        echo "Unable to determine repository name."
        return 1
    fi

    if [ -z "${MAIN_BRANCHES[$repo]}" ]; then
        MAIN_BRANCHES[$repo]=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
    fi
    echo "${MAIN_BRANCHES[$repo]}"
}

commits_on_branch() {
    check_git_repo || return 1

    if [ "$(current_branch)" = "$(gitmain)" ]; then
        git rev-list --count $(gitmain)
    else
        git rev-list --count $(gitmain)..$(current_branch)
    fi
}

gri() {
    check_git_repo || return 1

    local main_branch=$(gitmain)
    local current_branch=$(current_branch)
    if [ "$current_branch" = "$main_branch" ]; then
        echo "You are on the main branch with $(commits_on_branch) commits."
        echo "Rebasing and force pushing the main branch is dangerous."
        read -p "How many commits do you want to interactively rebase? " rebase_count
        git rebase -i HEAD~$rebase_count
    else
        local commit_count=$(commits_on_branch)
        if [ $? -ne 0 ]; then
            echo "Error: Unable to determine the number of commits on the branch."
            return 1
        fi
        git rebase -i HEAD~$commit_count
    fi
}

gc-release-as() {
    check_git_repo || return 1

    if [ -z "$1" ]; then
        echo "Usage: release_as <version>"
        return 1
    fi

    version=$1
    git commit --allow-empty -m "chore($(gitmain)): release $version" -m "Release-As: $version"
}

grm() {
    check_git_repo || return 1

    local main_branch=$(gitmain)
    if [ $? -ne 0 ]; then
        echo "Failed to determine the main branch."
        return 1
    fi

    git rebase "$main_branch"
}
alias gs='git status'
alias gl='git log'
alias glo='git log --oneline --graph --decorate'
alias gb='git branch'
alias gbo='printf "Current Branch -> \033[01;36m$(parse_git_branch)\033[00m\\n"'
alias gco='git checkout'
alias gc='git commit -m'
alias gca='git add . && git commit -m'
alias gps='git push'
gpsupstream() {
    check_git_repo || return 1

    local branches=$(git remote -v | awk '{print $1}' | uniq)
    if [ $(echo "$branches" | wc -l) -eq 1 ]; then
        local upstream_branch=$(echo "$branches" | head -n 1)
    else
        echo "Available upstream branches:"
        echo "$branches"
        read -p "Enter the upstream branch to set: " upstream_branch
    fi

    if [[ -z "$upstream_branch" ]]; then
        echo "No upstream branch entered. Please try again."
        return 1
    fi

    git push --set-upstream "$upstream_branch" $(current_branch)
}
alias gpu='git pull'
alias gpur='git pull --rebase'
alias gss='git stash save'
alias gconfig='git config --global --edit'
alias gpf='git push --force'
gfo() {
    check_git_repo || return 1

    git fetch origin $(gitmain):$(gitmain)
}
alias gswc='git switch -c'

check_and_pull() {
    local switch_output="$1"
    if [ -n "$switch_output" ]; then
        echo "$switch_output"
    fi
    if echo "$switch_output" | grep -q "use \"git pull\" to update your local branch"; then
        read -p "Your branch is behind. Do you want to run 'git pull'? [y/N] [r]ebase: " confirm_pull
        if [[ "$confirm_pull" =~ ^[Yy]$ ]]; then
            git pull
        elif [[ "$confirm_pull" =~ ^[Yy][Rr]$ ]]; then
            git pull --rebase
        else
            echo "Skipped 'git pull'."
        fi
    fi
}

gswm(){
    check_git_repo || return 1

    local switch_output=$(git switch $(gitmain))
    is_upstream_branch
    check_and_pull "$switch_output"
}

gsw() {
    check_git_repo || return 1

    if [ -z "$1" ]; then
        local branches=($(git branch --format='%(refname:short)'))
        local current_branch=$(current_branch)
        echo "Available branches:"
        for i in "${!branches[@]}"; do
            if [ "${branches[$i]}" = "$current_branch" ]; then
                echo -e "  $i) \033[0;32m${branches[$i]}\033[0m"
            else
                echo "  $i) ${branches[$i]}"
            fi
        done
        echo ""
        read -p "Select a branch to switch to: " branch_index
        if [[ -z "${branches[$branch_index]}" ]]; then
            echo "Invalid selection. Please try again."
            return 1
        fi
        local switch_output=$(git switch "${branches[$branch_index]}")
    else
        local switch_output=$(git switch "$1")
    fi

    is_upstream_branch
    check_and_pull "$switch_output"
}
alias gsw-='git switch - && is_upstream_branch'
alias gcnoverify='git commit --no-verify'
alias gcempty='git commit --allow-empty -m "chore(drop): trigger CI (DROP ME)"'
alias gitundolast='git reset --soft HEAD~1'
gitcleanup() {
    check_git_repo || return 1

    git fetch --prune
    local branches_to_delete=$(git branch -vv | grep ": gone]" | awk '{print $1}')
    if [ -z "$branches_to_delete" ]; then
        echo "No branches to clean up."
    else
        echo "Cleaning up the following branches:"
        echo "$branches_to_delete"
        echo "$branches_to_delete" | xargs -r git branch -D
    fi
}
gbd() {
    check_git_repo || return 1

    local branches=($(git branch --format='%(refname:short)'))
    local current_branch=$(current_branch)
    echo "Available branches:"
    for i in "${!branches[@]}"; do
        if [ "${branches[$i]}" = "$current_branch" ]; then
            echo -e "  $i) \033[0;32m${branches[$i]}\033[0m"
        else
            echo "  $i) ${branches[$i]}"
        fi
    done
    echo ""
    read -p "Select a branch to delete: " branch_index
    if [[ -z "${branches[$branch_index]}" ]]; then
        echo "Invalid selection. Please try again."
        return 1
    fi
    local branch_to_delete="${branches[$branch_index]}"
    read -p "Are you sure you want to delete the branch '$branch_to_delete'? [y/N] " confirmation
    if [[ "$confirmation" =~ ^[Yy]$ ]]; then
        git branch -d "$branch_to_delete"
    else
        echo "Branch deletion cancelled."
    fi
}
alias open-alias-repo='( xdg-open https://github.com/mariugul/bash-aliases &> /dev/null & )'

# Github CLI
# create PR on current branch
prcreate() {
    check_git_repo || return 1

    gh pr create --base $(gitmain) --head $(current_branch)
}
alias prview="echo 'Opening PR in browser.' && gh pr view -w > /dev/null 2>&1 & disown"
prcheckout() {
    check_git_repo || return 1

    # Checks out a GitHub PR when opened from a forked repo
    read -p "Enter the PR number to checkout: " pr_number
    if [[ ! -z "$pr_number" ]]; then
        gh pr checkout "$pr_number"
    else
        echo "No PR number entered. Please try again."
    fi
}

# Aliases
alias bash-rc='code ~/.bashrc'
alias bash-aliases='code ~/.bash_aliases'
alias sourcebashrc='source ~/.bashrc && echo "Bash aliases reloaded."'
alias c='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias upgrade-aliases='bash <(curl -sS https://raw.githubusercontent.com/mariugul/bash-aliases/main/install.sh)'

# Aliases for apt update and upgrade
alias apt-update='sudo apt-get update'
alias apt-upgrade='sudo apt-get upgrade -y'

# Show help for commands
show-help() {
    local main_branch=$(gitmain)
    local current_branch=$(current_branch)

    echo "Available commands:"
    echo ""
    echo "General:"
    echo "  c               : clear the terminal"
    echo "  ..              : go up one directory"
    echo "  ...             : go up two directories"
    echo "  ....            : go up three directories"
    echo "  .....           : go up four directories"
    echo "  bash-rc         : open .bashrc file in VS Code"
    echo "  bash-aliases    : open .bash_aliases file in VS Code"
    echo "  sourcebashrc    : apply changes to .bashrc file"
    echo "  upgrade-aliases : upgrade bash aliases. Add --dev to install local version of the bash-aliases file."
    echo "  open-alias-repo : open the bash-aliases GitHub repository in the default web browser"
    echo "  apt-update      : sudo apt-get update"
    echo "  apt-upgrade     : sudo apt-get upgrade"
    echo ""
    echo "Git:"
    echo "  gri             : git rebase -i"
    echo "  grm             : git rebase $main_branch"
    echo "  gs              : git status"
    echo "  gl              : git log"
    echo "  glo             : git log --oneline --graph --decorate"
    echo "  gb              : git branch"
    echo "  gbd             : Delete a local branch from the list"
    echo "  gbo             : show current branch"
    echo "  gco             : git checkout"
    echo "  gc              : git commit -m"
    echo "  gca             : git add . && git commit -m"
    echo "  gps             : git push"
    echo "  gpsupstream     : git push --set-upstream origin $current_branch"
    echo "  gpu             : git pull"
    echo "  gpur            : git pull --rebase"
    echo "  gss             : git stash save"
    echo "  gconfig         : git config --global --edit"
    echo "  gpf             : git push --force"
    echo "  gfo             : git fetch origin $main_branch:$main_branch"
    echo "  gsw             : git switch"
    echo "  gswc            : git switch -c"
    echo "  gswm            : git switch $main_branch"
    echo "  gsw-            : git switch -"
    echo "  gcnoverify      : git commit --no-verify"
    echo "  current_repo    : get the current repository name"
    echo "  commits_on_branch : get the number of commits on the current branch"
    echo "  gitundolast     : git reset --soft HEAD~1"
    echo "  gitcleanup      : git fetch --prune && git branch -vv | grep ': gone]' | awk '{print \$1}' | xargs -r git branch -D"
    echo ""
    echo "GitHub CLI:"
    echo "  prcreate        : gh pr create --base $main_branch --head $$current_branch"
    echo "  prcreate        : gh pr create --base $main_branch --head $current_branch"
    echo "  prcheckout      : checkout a GitHub PR by number"
    echo ""
    echo "Methods:"
    echo "  current_repo    : get the current repository name"
    echo "  is_git_repo     : check if the current directory is a git repository"
    echo "  alias_add       : add a new alias"
    echo "  current_branch  : get the current git branch"
    echo "  gitmain         : get the $main_branch branch of the repository"
    echo "  commits_on_branch : get the number of commits on the current branch"
    echo "  gc-release-as   : create a release commit with a specified version"
    echo "  parse_git_branch: parse and display the current git branch"
}

# Check if the shell is in a git repository and print the current branch
if is_git_repo; then
    echo -e "Checked out on branch: \033[01;36m$(current_branch)\033[00m"
    git_status=$(git status > /dev/null 2>&1)
    check_and_pull "$git_status"
fi
