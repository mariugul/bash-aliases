#!/bin/bash
# Git Aliases
# Simple git command shortcuts and one-liners

# Basic git aliases
alias gs='git status'
alias gl='git log --stat'
alias glo='git log --oneline --graph --decorate'
alias gb='git branch'
alias gbo='printf "Current Branch -> \033[01;36m$(parse_git_branch)\033[00m\\n"'
alias gco='git checkout'
alias gc='git commit -m'
alias gca='git add . && git commit -m'
alias gpu='git pull'
alias gpur='git pull --rebase'
alias gss='git stash save'
alias gconfig='git config --global --edit'
alias gpf='git push --force'
alias gswc='git switch -c'
alias gsw-='git switch - && is-upstream-branch'
alias gcnoverify='git commit --no-verify'
alias gcempty='git commit --allow-empty -m "chore(drop): trigger CI (DROP ME)"'
alias gitundolast='git reset --soft HEAD~1'
alias gf='git fetch'
alias gfa='git fetch --all'

# Git log functions
glb() {
    # Show the git log for the current branch
    git log --first-parent "$(git-first-commit)"..HEAD --decorate --graph --stat
}

glob() {
    # Show the git log for the current branch
    git log --oneline --first-parent "$(git-first-commit)"..HEAD
}

glr() {
    # Show commit messages between two commits/branches
    # Usage: glr <from> <to>
    if [ $# -ne 2 ]; then
        echo "Usage: glr <from> <to>"
        return 1
    fi
    git log "$1"^.."$2"
}

glm() {
    # Show full commit messages between two points
    # Usage: glm <from> <to>
    if [ $# -ne 2 ]; then
        echo "Usage: glm <from> <to>"
        return 1
    fi
    git log --pretty=format:"%B%n---" "$1"^.."$2"
}

# Git commit functions
gc-release-as() {
    check-git-repo || return 1

    if [ -z "${1}" ]; then
        echo "Usage: release_as <version>"
        return 1
    fi

    version=${1}
    git commit --allow-empty -m "chore($(gitmain)): release ${version}" -m "Release-As: ${version}"
}

# GitHub CLI aliases
alias prview="echo 'Opening PR in browser.' && gh pr view -w > /dev/null 2>&1 & disown"
