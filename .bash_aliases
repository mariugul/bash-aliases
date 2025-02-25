# Methods

current_repo() {
    git remote get-url origin 2> /dev/null | sed -n 's#.*/\([^.]*\)\.git#\1#p'
}

is_git_repo() {
    git rev-parse --is-inside-work-tree 2> /dev/null
}

alias_add() {
    echo "alias $1='$2'" >> ~/.bash_aliases
    source ~/.bash_aliases
}

current_branch() {
    git branch --show-current
}

declare -A MAIN_BRANCHES

function gitmain() {
    local repo=$(current_repo)
    if [ -z "${MAIN_BRANCHES[$repo]}" ]; then
        MAIN_BRANCHES[$repo]=$(git remote show origin | grep 'HEAD branch' | awk '{print $NF}')
    fi
    echo "${MAIN_BRANCHES[$repo]}"
}

commits_on_branch() {
    if [ "$(current_branch)" = "$(gitmain)" ]; then
        git rev-list --count $(gitmain)
    else
        git rev-list --count $(gitmain)..$(current_branch)
    fi
}

gri() {
    local main_branch=$(gitmain)
    local current_branch=$(current_branch)
    if [ "$current_branch" = "$main_branch" ]; then
        echo "You are on the main branch with $(commits_on_branch) commits."
        echo "Rebasing and force pushing the main branch is dangerous."
        read -p "How many commits do you want to interactively rebase? " rebase_count
        git rebase -i HEAD~$rebase_count
    else
        git rebase -i HEAD~$(commits_on_branch)
    fi
}

gc-release-as() {
  if [ -z "$1" ]; then
    echo "Usage: release_as <version>"
    return 1
  fi

  version=$1
  git commit --allow-empty -m "chore($(gitmain)): release $version" -m "Release-As: $version"
}

function parse_git_branch() {
    git branch 2>/dev/null | grep \* | sed 's/* //'
}

# Git aliases
alias grm="git rebase $(gitmain)"
alias gs='git status'
alias gl='git log'
alias glo='git log --oneline --graph --decorate'
alias gb='git branch'
alias gbo='printf "Current Branch -> \033[01;36m$(parse_git_branch)\033[00m\\n"'
alias gco='git checkout'
alias gc='git commit -m'
alias gca='git add . && git commit -m'
alias gps='git push'
alias gpsupstream='git push --set-upstream origin $(git branch --show-current)'
alias gpu='git pull'
alias gpur='git pull --rebase'
alias gss='git stash save'
alias gconfig='git config --global --edit'
alias gpf='git push --force'
alias gfo="git fetch origin $(gitmain):$(gitmain)"
alias gsw='git switch'
alias gswc='git switch -c'
alias gswm="git switch $(gitmain)"
alias gsw-='git switch -'
alias gcnoverify='git commit --no-verify'
alias gcempty='git commit --allow-empty -m "chore(drop): trigger CI (DROP ME)"'
alias gitundolast='git reset --soft HEAD~1'
alias gitcleanup='git fetch --prune && git branch -vv | grep ": gone]" | awk "{print $1}" | xargs -r git branch -D'


# Github CLI
# create PR on current branch
alias prcreate="gh pr create --base $(gitmain) --head \$(git branch --show-current)"
alias prview="echo 'Opening PR in browser.' && gh pr view -w > /dev/null 2>&1 & disown"
function prcheckout() {
    # Checks out a GitHub PR when opened from a forked repo
    read -p "Enter the PR number to checkout: " pr_number
    if [[ ! -z "$pr_number" ]]; then
        gh pr checkout "$pr_number"
    else
        echo "No PR number entered. Please try again."
    fi
}

# Aliases
alias ..='cd ..'
alias bash-rc='code ~/.bashrc'
alias bash-aliases='code ~/.bash_aliases'
alias sourcebashrc='source ~/.bashrc && echo "Bash aliases reloaded."'
alias c='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias upgrade-aliases='bash <(curl -sS https://raw.githubusercontent.com/mariugul/bash-aliases/main/install.sh) && $(sourcebashrc)'

# Show help for commands
function show-help() {
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
    echo "  upgrade-aliases : upgrade bash aliases"
    echo ""
    echo "Git:"
    echo "  gri             : git rebase -i"
    echo "  grm             : git rebase $(gitmain)"
    echo "  gs              : git status"
    echo "  gl              : git log"
    echo "  glo             : git log --oneline --graph --decorate"
    echo "  gb              : git branch"
    echo "  gbo             : show current branch"
    echo "  gco             : git checkout"
    echo "  gc              : git commit -m"
    echo "  gca             : git add . && git commit -m"
    echo "  gps             : git push"
    echo "  gpsupstream     : git push --set-upstream origin \$(git branch --show-current)"
    echo "  gpu             : git pull"
    echo "  gpur            : git pull --rebase"
    echo "  gss             : git stash save"
    echo "  gconfig         : git config --global --edit"
    echo "  gpf             : git push --force"
    echo "  gfo             : git fetch origin $(gitmain):$(gitmain)"
    echo "  gsw             : git switch"
    echo "  gswc            : git switch -c"
    echo "  gswm            : git switch $(gitmain)"
    echo "  gsw-            : git switch -"
    echo "  gcnoverify      : git commit --no-verify"
    echo "  gcempty         : git commit --allow-empty -m 'chore(drop): trigger CI (DROP ME)'"
    echo "  gitundolast     : git reset --soft HEAD~1"
    echo "  gitcleanup      : git fetch --prune && git branch -vv | grep ': gone]' | awk '{print \$1}' | xargs -r git branch -D"
    echo ""
    echo "GitHub CLI:"
    echo "  prcreate        : gh pr create --base $(gitmain) --head \$(git branch --show-current)"
    echo "  prview          : open PR in browser"
    echo "  prcheckout      : checkout a GitHub PR by number"
    echo ""
    echo "Methods:"
    echo "  current_repo    : get the current repository name"
    echo "  is_git_repo     : check if the current directory is a git repository"
    echo "  alias_add       : add a new alias"
    echo "  current_branch  : get the current git branch"
    echo "  gitmain         : get the $(gitmain) branch of the repository"
    echo "  commits_on_branch : get the number of commits on the current branch"
    echo "  gc-release-as   : create a release commit with a specified version"
    echo "  parse_git_branch: parse and display the current git branch"
}
