# Bash Aliases

This repository contains a collection of useful bash aliases and functions to enhance your command-line productivity.

## Installation

To install the bash aliases, run the following command in your terminal:

```bash
bash <(curl -sS https://raw.githubusercontent.com/mariugul/bash-aliases/main/install.sh) && source ~/.bashrc
```

## Usage

After installation, you can use the following aliases and functions:

```txt
$ show-help

Available Commands:

General Commands:
  c               : Clear the terminal screen
  ..[...]         : Move up one to four directories
  bash-rc         : Open the .bashrc file in VS Code
  bash-aliases    : Open the .bash_aliases file in VS Code
  sourcebashrc    : Apply changes to the .bashrc file
  sourcevenv      : Activate the Python virtual environment
  upgrade-aliases : Upgrade bash aliases (use --dev for local version)
  open-alias-repo : Open the bash-aliases GitHub repository
  apt-update      : Update package lists for upgrades
  apt-upgrade     : Upgrade all packages (update first)
  pipupgrade      : Upgrade pip to the latest version
  uvr             : Run Astral (uv run)
  uvi             : Invoke Astral (uv run invoke)
  alias-add       : Add a new alias. Usage: alias-add <alias_name> <command>
  myip            : Display your public IP address
  mkcd            : Create and navigate to a new directory
  diskspace       : Check disk space usage
  dirsize         : Check the size of a directory

Git Commands:
  gri             : Start an interactive rebase
  grm             : Rebase onto the main branch
  gs              : git status
  gl              : git log --stat
  gls             : Show git stats for commits on current branch. Usage: gls (concise) or gls -v (verbose)
  glo             : git log --oneline --graph --decorate
  glob            : Show a one-line log for the current branch
  glb             : Show a detailed log for the current branch
  glr             : Show commit messages between two commits/branches. Usage: glr <from> <to>
  glm             : Show full commit messages between two points. Usage: glm <from> <to>
  gb              : git branch
  gbd             : Delete local branches (interactive, multi-select)
  gbo             : Display the current branch name
  gco             : git checkout
  gc              : git commit -m
  gca             : git add . && git commit -m
  gcempty         : Create an empty commit to trigger CI
  gcnoverify      : git commit --no-verify
  gf              : git fetch
  gfa             : git fetch --all
  gfo             : Fetch main branch from primary remote
  gps             : git push (auto-sets upstream if needed)
  gpsupstream     : git push --set-upstream
  gpu             : git pull
  gpur            : git pull --rebase
  gpf             : git push --force
  gss             : git stash push
  gconfig         : git config --global --edit
  gsw             : git switch (interactive branch selector)
  gswc            : git switch -c (create new branch)
  gswm            : git switch main
  gsw-            : git switch - (previous branch)
  gitundolast     : git reset --soft HEAD~1
  gitcleanup      : Prune remotes and delete gone branches (interactive)
  sync-fork       : Sync a forked repo with upstream

GitHub CLI:
  prcreate        : Create a PR from current branch to main
  prcheckout      : Checkout a GitHub PR by number
  prview          : Open current PR in browser

Utility Functions:
  current-repo      : Get the name of the current git repository
  is-git-repo       : Check if the current directory is a git repository
  current-branch    : Get the name of the current git branch
  gitmain           : Get the main branch of the repository (cached)
  commits-on-branch : Get the number of commits on the current branch
  gc-release-as     : Create a release commit with a specified version
  git-first-commit  : Get the first commit of the current branch
```

## Updating Aliases

To get the newest updates from the aliases upstream, you can run the following command:

```bash
upgrade-aliases
```
