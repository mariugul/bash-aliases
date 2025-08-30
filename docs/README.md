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

Available commands:

General:
  c               : clear the terminal
  ..              : go up one directory
  ...             : go up two directories
  ....            : go up three directories
  .....           : go up four directories
  bash-rc         : open .bashrc file in VS Code
  bash-aliases    : open .bash_aliases file in VS Code
  sourcebashrc    : apply changes to .bashrc file
  upgrade-aliases : upgrade bash aliases. Add --dev to install local version of the bash-aliases file.
  open-alias-repo : open the bash-aliases GitHub repository in the default web browser

Git:
  gri             : git rebase -i
  grm             : git rebase main
  gs              : git status
  gl              : git log
  glo             : git log --oneline --graph --decorate
  gb              : git branch
  gbo             : show current branch
  gco             : git checkout
  gc              : git commit -m
  gca             : git add . && git commit -m
  gps             : git push
  gpsupstream     : git push --set-upstream origin main
  gpu             : git pull
  gpur            : git pull --rebase
  gss             : git stash save
  gconfig         : git config --global --edit
  gpf             : git push --force
  gfo             : git fetch origin main:main
  gsw             : git switch
  gswc            : git switch -c
  gswm            : git switch main
  gsw-            : git switch -
  gcnoverify      : git commit --no-verify
  current_repo    : get the current repository name
  commits_on_branch : get the number of commits on the current branch
  gitundolast     : git reset --soft HEAD~1
  gitcleanup      : git fetch --prune && git branch -vv | grep ': gone]' | awk '{print $1}' | xargs -r git branch -D

GitHub CLI:
  prcreate        : gh pr create --base main --head 795798current_branch
  prcreate        : gh pr create --base main --head main
  prcheckout      : checkout a GitHub PR by number

Methods:
  current_repo    : get the current repository name
  is_git_repo     : check if the current directory is a git repository
  alias_add       : add a new alias
  current_branch  : get the current git branch
  gitmain         : get the main branch of the repository
  commits_on_branch : get the number of commits on the current branch
  gc-release-as   : create a release commit with a specified version
  parse_git_branch: parse and display the current git branch
```

## Updating Aliases

To get the newest updates from the aliases upstream, you can run the following command:

```bash
upgrade-aliases
```
