# Bash Aliases

This repository contains a collection of useful bash aliases and functions to enhance your command-line productivity.

## Installation

### Linux/macOS

To install the bash aliases, run the following command in your terminal:

```bash
bash <(curl -sS https://raw.githubusercontent.com/mariugul/bash-aliases/main/install.sh) && source ~/.bashrc
```

### Windows (Git Bash)

For Windows users using Git Bash, use the Windows-specific installer:

```bash
bash <(curl -sS https://raw.githubusercontent.com/mariugul/bash-aliases/main/install-windows.sh) && source ~/.bash_profile
```

Or download and run locally:

```bash
curl -sSLo install-windows.sh https://raw.githubusercontent.com/mariugul/bash-aliases/main/install-windows.sh
bash install-windows.sh
source ~/.bash_profile
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

## Platform Compatibility

### Cross-Platform (Linux, macOS, Windows Git Bash)

These commands work on all platforms:

- **Git Commands**: All `g*` aliases (`gs`, `gl`, `gc`, `gco`, `gri`, `grm`, `gbd`, `gsw`, `gitcleanup`, `sync-fork`, etc.)
- **GitHub CLI**: `prcreate`, `prcheckout`, `prview` (requires `gh` CLI installed)
- **General**: `c` (clear), `..` navigation, `mkcd`, `myip`, `alias-add`, `pipupgrade`
- **Text Styling**: `text`, `bold`, `italic`, `underline` (ANSI colors work in Git Bash)
- **Utilities**: `current-repo`, `current-branch`, `gitmain`, `commits-on-branch`

### Linux/macOS Only

These commands are not available on Windows:

| Command | Reason |
|---------|--------|
| `apt-update`, `apt-upgrade` | Debian/Ubuntu package manager |
| `open-alias-repo` | Uses `xdg-open` (Linux desktop) |
| `sourcevenv` | Uses Unix path `.venv/bin/activate` |
| `bash-rc`, `bash-aliases` | Assumes `code` command in PATH |
| `sourcebashrc` | References `.bashrc` instead of `.bash_profile` |
| `diskspace` (`df -h`) | Different output/format on Windows |
| `dirsize` (`du -sh`) | Behaves differently on Windows |

### Windows-Specific Notes

- The Windows installer uses `.bash_profile` instead of `.bashrc`
- The `upgrade-aliases` command will still work but references the Linux install script
- VS Code `code` command must be in your PATH for editor aliases to work
- Python virtual environments use `Scripts/activate` on Windows, not `bin/activate`

## Updating Aliases

To get the newest updates from the aliases upstream, you can run the following command:

```bash
upgrade-aliases
```

On Windows (Git Bash), run:

```bash
bash <(curl -sS https://raw.githubusercontent.com/mariugul/bash-aliases/main/install-windows.sh)
source ~/.bash_profile
```
