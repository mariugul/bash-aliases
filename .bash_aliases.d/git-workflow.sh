#!/bin/bash
# Git Workflow Functions
# Complex interactive git operations and workflow commands

is-upstream-branch() {
    check-git-repo || return 1

    local current_branch=$(current-branch)
    local upstream_branch=$(git rev-parse --abbrev-ref "${current_branch}@{upstream}" 2> /dev/null)

    if [ -z "${upstream_branch}" ]; then
        echo "The branch '${current_branch}' is not tracking any upstream branch."
        read -r -p "Do you want to set the upstream branch now? [y/N] " set_upstream
        if [[ "${set_upstream}" =~ ^[Yy]$ ]]; then
            gpsupstream
        else
            echo "Skipped setting upstream branch."
        fi
        return 1
    else
        echo "The branch '${current_branch}' is tracking the upstream branch '${upstream_branch}'."
        return 0
    fi
}

gri() {
    check-git-repo || return 1

    local main_branch=$(gitmain)
    local current_branch=$(current-branch)
    if [ "${current_branch}" = "${main_branch}" ]; then
        echo "You are on the main branch with $(commits-on-branch) commits."
        echo "Rebasing and force pushing the main branch is dangerous."
        read -r -p "How many commits do you want to interactively rebase? " rebase_count
        git rebase -i HEAD~${rebase_count}
    else
        local commit_count=$(commits-on-branch)
        if ! commits-on-branch >/dev/null; then
            echo "Error: Unable to determine the number of commits on the branch."
            return 1
        fi
        git rebase -i HEAD~${commit_count}
    fi
}

grm() {
    check-git-repo || return 1

    local main_branch
    if ! main_branch=$(gitmain); then
        echo "Failed to determine the main branch."
        return 1
    fi

    git rebase "${main_branch}"
}

gps() {
    check-git-repo || return 1
    local git_push
    git_push=$(git push 2>&1)

    if echo "${git_push}" | grep -q "fatal: The current branch"; then
        echo -e "The current branch is not tracking any remote branch.\n"
        gpsupstream
        return
    fi

    echo "${git_push}"
}

gpsupstream() {
    check-git-repo || return 1

    local branches=$(git remote -v | awk '{print $1}' | uniq)
    if [ "$(echo "${branches}" | wc -l)" -eq 1 ]; then
        local upstream_branch=$(echo "${branches}" | head -n 1)
    else
        echo "Available upstream branches:"
        for branch in ${branches}; do
            echo " - ${branch}"
        done
        read -r -p "Enter the upstream branch to set: " upstream_branch
    fi

    if [[ -z "${upstream_branch}" ]]; then
        echo "No upstream branch entered. Please try again."
        return 1
    fi

    git push --set-upstream "${upstream_branch}" "$(current-branch)"
}

gfo() {
    check-git-repo || return 1

    local primary_remote=$(get-primary-remote)
    if ! get-primary-remote >/dev/null || [ -z "${primary_remote}" ]; then
        echo "Unable to determine primary remote."
        return 1
    fi
    
    git fetch "${primary_remote}" "$(gitmain):$(gitmain)"
}

check-and-pull() {
    local switch_output="$1"
    local print_output="$2"
    if [ -n "${switch_output}" ] && [ "${print_output}" = true ]; then
        echo "${switch_output}"
    fi
    if echo "${switch_output}" | grep -q "use \"git pull\" to update your local branch"; then
        local behind_commits=$(echo "${switch_output}" | grep -oP '(?<=by )\d+(?= commits)')
        echo "Your branch is behind by ${behind_commits} commits."
        read -r -p "Do you want to run 'git pull'? [y/N] [r]ebase: " confirm_pull
        if [[ "${confirm_pull}" =~ ^[Yy]$ ]]; then
            git pull
        elif [[ "${confirm_pull}" =~ ^[Rr]$ ]]; then
            git pull --rebase
        else
            echo "Skipped 'git pull'."
        fi
    fi
}

gswm(){
    check-git-repo || return 1

    local switch_output=$(git switch "$(gitmain)")
    is-upstream-branch
    check-and-pull "${switch_output}" true
}

gsw() {
    check-git-repo || return 1

    if [ -z "$1" ]; then
        local all_branches
        mapfile -t all_branches < <(git branch --format='%(refname:short)')
        # Use helper to sort branches
        local sorted_output
        sorted_output=$(sorted-branches-with-main-first "${all_branches[@]}")
        read -ra branches <<< "${sorted_output}"
        local current_branch=$(current-branch)
        echo "Available branches:"
        for i in "${!branches[@]}"; do
            if [ "${branches[${i}]}" = "${current_branch}" ]; then
                echo -e "  ${i}) \033[0;32m${branches[${i}]}\033[0m"
            else
                echo "  ${i}) ${branches[${i}]}"
            fi
        done
        echo ""
        read -r -p "Select a branch to switch to: " branch_index
        if [[ -z "${branches[${branch_index}]}" ]]; then
            echo "Invalid selection. Please try again."
            return 1
        fi
        local switch_output=$(git switch "${branches[${branch_index}]}")
    else
        local switch_output=$(git switch "$1")
    fi

    is-upstream-branch
    check-and-pull "${switch_output}" true
}

gitcleanup() {
    check-git-repo || return 1

    # Show current remotes for context
    local remotes=$(git remote)
    local remote_count=$(echo "${remotes}" | wc -l)
    echo "Found ${remote_count} remote(s): $(echo "${remotes}" | tr '\n' ' ')"
    
    echo "Fetching and pruning from all remotes..."
    if ! git fetch --all --prune; then
        echo "Warning: Some remotes may have failed to fetch. Continuing..."
    fi

    local branches_to_delete=$(gone-branches)
    branches_to_delete="$(echo -n "${branches_to_delete}" | xargs)"  # trims whitespace
    if [ -z "${branches_to_delete}" ]; then
        echo "No branches to clean up."
        return
    fi

    echo "Found branches with deleted upstream remotes:"
    for branch in ${branches_to_delete}; do
        echo "  - ${branch}"
    done
    
    read -r -p "Delete these branches? [y/N] " confirm_delete
    if [[ "${confirm_delete}" =~ ^[Yy]$ ]]; then
        echo "Deleting branches..."
        git branch --delete --force ${branches_to_delete}
        echo "Cleanup completed."
    else
        echo "Branch deletion cancelled."
    fi
}

gbd() {
    check-git-repo || return 1

    local all_branches
    mapfile -t all_branches < <(git branch --format='%(refname:short)')
    # Use helper to sort branches
    local sorted_output
    sorted_output=$(sorted-branches-with-main-first "${all_branches[@]}")
    read -ra branches <<< "${sorted_output}"
    local current_branch=$(current-branch)
    echo "Available branches:"
    for i in "${!branches[@]}"; do
        if [ "${branches[${i}]}" = "${current_branch}" ]; then
            echo -e "  ${i}) \033[0;32m${branches[${i}]}\033[0m"
        else
            echo "  ${i}) ${branches[${i}]}"
        fi
    done
    echo ""
    read -r -p "Select a branch to delete: " branch_index
    if [[ -z "${branches[${branch_index}]}" ]]; then
        echo "Invalid selection. Please try again."
        return 1
    fi
    local branch_to_delete="${branches[${branch_index}]}"
    read -r -p "Are you sure you want to delete the branch '${branch_to_delete}'? [y/N] " confirmation
    if [[ "${confirmation}" =~ ^[Yy]$ ]]; then
        git branch -d "${branch_to_delete}"
    else
        echo "Branch deletion cancelled."
    fi
}

sync-fork() {
    check-git-repo || return 1

    local main_branch=$(gitmain)
    if [ -z "${main_branch}" ]; then
        echo "Failed to determine the main branch."
        return 1
    fi

    if ! git remote get-url upstream &> /dev/null; then
        echo "Error: 'upstream' remote does not exist."
        echo "Please add it by running 'git remote add upstream https://github.com/original-repo-url.git'"
        echo "It's expected that the upstream remote points to the original repository and the forked repository is added as 'origin'."
        return 1
    fi

    # For sync-fork, we specifically want to push to origin (the fork)
    # even if upstream is the primary remote for other operations
    if ! git remote get-url origin &> /dev/null; then
        echo "Error: 'origin' remote does not exist."
        echo "For fork syncing, 'origin' should point to your fork."
        return 1
    fi

    echo "Fetching upstream..."
    git fetch upstream

    echo "Rebasing upstream/${main_branch} onto ${main_branch}..."
    git rebase upstream/${main_branch} ${main_branch}

    echo "Force pushing ${main_branch} to origin (your fork)..."
    git push origin ${main_branch} --force
}

# GitHub CLI functions
prcreate() {
    check-git-repo || return 1

    gh pr create --base "$(gitmain)" --head "$(current-branch)"
}

prcheckout() {
    check-git-repo || return 1

    # Checks out a GitHub PR when opened from a forked repo
    read -r -p "Enter the PR number to checkout: " pr_number
    if [[ -n "${pr_number}" ]]; then
        gh pr checkout "${pr_number}"
    else
        echo "No PR number entered. Please try again."
    fi
}
