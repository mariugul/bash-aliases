# Bash Aliases

This repository contains a collection of useful bash aliases and functions to enhance your command-line productivity.

## Installation

To install the bash aliases, run the following command in your terminal:

```bash
bash <(curl -sS https://raw.githubusercontent.com/mariugul/bash-aliases/main/install.sh)
```

This command will:
- Run the script to install the bash aliases.

## Usage

After installation, you can use the following aliases and functions:

### Git Aliases
- `grm`: Rebase onto the main branch.
- `gri`: Interactively rebase commits.
- `gs`: Show the git status.
- `gl`: Show the git log.
- `glo`: Show the git log in a one-line format with graph and decorations.
- `gb`: List git branches.
- `gbo`: Show the current branch.
- `gco`: Checkout a git branch.
- `gc`: Commit with a message.
- `gca`: Add all changes and commit with a message.
- `gps`: Push changes to the remote repository.
- `gpsupstream`: Push the current branch and set upstream.
- `gpu`: Pull changes from the remote repository.
- `gpur`: Pull changes with rebase.
- `gss`: Save changes to the stash.
- `gconfig`: Edit global git configuration.
- `gpf`: Force push changes.
- `gfo`: Fetch the main branch from the origin.
- `gsw`: Switch branches.
- `gswc`: Create and switch to a new branch.
- `gswm`: Switch to the main branch.
- `gsw-`: Switch to the previous branch.
- `gcnoverify`: Commit without verification.
- `gcempty`: Create an empty commit.
- `gitundolast`: Undo the last commit.
- `gitcleanup`: Clean up local branches that no longer exist on the remote.

### GitHub CLI Aliases
- `prcreate`: Create a pull request on the current branch.
- `prview`: Open the pull request in the browser.
- `prcheckout`: Checkout a GitHub PR by number.

### General Aliases
- `..`: Go up one directory.
- `...`: Go up two directories.
- `....`: Go up three directories.
- `.....`: Go up four directories.
- `bash-rc`: Open the `.bashrc` file in VS Code.
- `bash-aliases`: Open the `.bash_aliases` file in VS Code.
- `sourcebashrc`: Apply changes to the `.bashrc` file.
- `c`: Clear the terminal.
- `upgrade-aliases`: Upgrade bash aliases. Add `--dev` to install the local version of the bash-aliases file.

### Methods
- `current_repo`: Get the current repository name.
- `is_git_repo`: Check if the current directory is a git repository.
- `alias_add`: Add a new alias.
- `current_branch`: Get the current git branch.
- `gitmain`: Get the main branch of the repository.
- `commits_on_branch`: Get the number of commits on the current branch.
- `gc-release-as`: Create a release commit with a specified version.
- `parse_git_branch`: Parse and display the current git branch.

### Help
- `show-help`: Show available commands and their descriptions.

## Updating Aliases

To get the newest updates from the aliases upstream, you can run the following command:

```bash
upgrade-aliases
```

This command will fetch the latest version of the bash aliases and apply the updates.
