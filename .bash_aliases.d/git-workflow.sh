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
    local git_push push_status
    git_push=$(git push 2>&1) && push_status=0 || push_status=$?

    if echo "${git_push}" | grep -q "fatal: The current branch"; then
        echo -e "The current branch is not tracking any remote branch.\n"
        gpsupstream
        return
    fi

    echo "${git_push}"
    return "${push_status}"
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

    local primary_remote main_branch
    primary_remote=$(get-primary-remote) || { echo "Unable to determine primary remote."; return 1; }
    if [ -z "${primary_remote}" ]; then
        echo "Unable to determine primary remote."
        return 1
    fi
    main_branch=$(gitmain) || return 1

    if [ "$(current-branch)" = "${main_branch}" ]; then
        # main is checked out here: fetching "main:main" is refused.
        # Update the remote-tracking ref and fast-forward instead.
        git fetch "${primary_remote}" "${main_branch}" || return 1
        git merge --ff-only "${primary_remote}/${main_branch}"
    else
        git fetch "${primary_remote}" "${main_branch}:${main_branch}"
    fi
}

check-and-pull() {
    local switch_output="${1:-}"
    local print_output="${2:-}"
    if [ -n "${switch_output}" ] && [ "${print_output}" = true ]; then
        echo "${switch_output}"
    fi

    # Ask git directly instead of parsing human `git status` output — robust
    # across locales, detects diverged branches, and needs no GNU grep -P.
    local behind ahead
    behind=$(git rev-list --count "HEAD..@{upstream}" 2>/dev/null) || return 0
    ahead=$(git rev-list --count "@{upstream}..HEAD" 2>/dev/null)

    if [ "${behind:-0}" -le 0 ]; then
        return 0
    fi

    if [ "${ahead:-0}" -gt 0 ]; then
        echo "Your branch has diverged from upstream (ahead ${ahead}, behind ${behind})."
    else
        echo "Your branch is behind upstream by ${behind} commit(s)."
    fi
    read -r -p "Do you want to run 'git pull'? [y/N] [r]ebase: " confirm_pull
    if [[ "${confirm_pull}" =~ ^[Yy]$ ]]; then
        git pull
    elif [[ "${confirm_pull}" =~ ^[Rr]$ ]]; then
        git pull --rebase
    else
        echo "Skipped 'git pull'."
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
        local all_branches=() line
        while IFS= read -r line; do
            all_branches+=("${line}")
        done < <(git branch --format='%(refname:short)')
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

# Emit one "branch<TAB>path<TAB>flags" line per worktree, primary worktree
# first. Detached or bare entries have an empty branch field.
_gitcleanup-worktrees() {
    git worktree list --porcelain | awk '
        /^worktree / { if (path != "") print br "\t" path "\t" flags
                       path = substr($0, 10); br = ""; flags = "" }
        /^branch /   { br = substr($0, 8); sub(/^refs\/heads\//, "", br) }
        /^locked/    { flags = flags "locked," }
        END          { if (path != "") print br "\t" path "\t" flags }
    '
}

# Canonicalize a path for comparison: resolve symlinks when the directory
# exists, echo the input unchanged otherwise.
_gitcleanup-canon-path() {
    (cd "${1}" 2> /dev/null && pwd -P) || printf '%s\n' "${1}"
}

# Print " [unmerged: N commit(s)]" when <branch> has commits that are not
# reachable from <main>. Prints nothing when the branch is fully merged or
# the count cannot be determined.
_gitcleanup-unmerged-marker() {
    local branch="${1}" main="${2}"
    [ -n "${main}" ] || return 0
    local count
    count=$(git rev-list --count "${main}..${branch}" 2> /dev/null) || return 0
    if [ "${count}" -eq 1 ]; then
        printf ' [unmerged: 1 commit]'
    elif [ "${count}" -gt 1 ]; then
        printf ' [unmerged: %s commits]' "${count}"
    fi
}

gitcleanup() {
    check-git-repo || return 1

    local dry_run=false assume_yes=false
    while [ $# -gt 0 ]; do
        case "${1}" in
            --dry-run|-n) dry_run=true ;;
            --yes|-y)     assume_yes=true ;;
            --help|-h)
                echo "Usage: gitcleanup [--dry-run|-n] [--yes|-y]"
                echo ""
                echo "Delete local branches whose upstream is gone, including their"
                echo "linked worktrees. Candidates with commits not on the main"
                echo "branch are flagged with an unmerged marker."
                echo ""
                echo "  --dry-run, -n  List what would be deleted and exit"
                echo "  --yes, -y      Delete without asking for confirmation"
                return 0
                ;;
            *)
                echo "Usage: gitcleanup [--dry-run|-n] [--yes|-y]" >&2
                return 1
                ;;
        esac
        shift
    done

    # Show current remotes for context
    local remotes=$(git remote)
    local remote_count=$(grep -c . <<< "${remotes}")
    echo "Found ${remote_count} remote(s): $(echo "${remotes}" | tr '\n' ' ')"

    echo "Fetching and pruning from all remotes..."
    if ! git fetch --all --prune; then
        echo "Warning: Some remotes may have failed to fetch. Continuing..."
    fi

    # Drop stale registrations for worktree directories removed by hand
    git worktree prune

    local branches_to_delete=$(gone-branches)
    branches_to_delete="$(echo -n "${branches_to_delete}" | xargs)"  # trims whitespace
    if [ -z "${branches_to_delete}" ]; then
        echo "No branches to clean up."
        return
    fi

    # A branch checked out in a linked worktree needs that worktree removed
    # before the branch can be deleted.
    local wt_table=$(_gitcleanup-worktrees)
    local current_wt=$(_gitcleanup-canon-path "$(git rev-parse --show-toplevel)")
    local primary_wt=$(_gitcleanup-canon-path "$(echo "${wt_table}" | head -n 1 | cut -f 2)")

    local -a del_branches=() rm_worktrees=() skipped=()
    local branch wt_path wt_flags entry
    for branch in ${branches_to_delete}; do
        entry=$(awk -F '\t' -v b="${branch}" '$1 == b { print $2 "\t" $3; exit }' <<< "${wt_table}")
        if [ -z "${entry}" ]; then
            del_branches+=("${branch}")
            continue
        fi
        wt_path="${entry%%$'\t'*}"
        wt_flags="${entry#*$'\t'}"

        if [ "$(_gitcleanup-canon-path "${wt_path}")" = "${primary_wt}" ]; then
            skipped+=("${branch} (checked out in the primary worktree)")
        elif [ "$(_gitcleanup-canon-path "${wt_path}")" = "${current_wt}" ]; then
            skipped+=("${branch} (checked out in the current worktree)")
        elif [[ "${wt_flags}" == *locked* ]]; then
            skipped+=("${branch} (worktree is locked: ${wt_path})")
        elif [ -n "$(git -C "${wt_path}" status --porcelain 2> /dev/null)" ]; then
            skipped+=("${branch} (worktree has uncommitted changes: ${wt_path})")
        else
            rm_worktrees+=("${branch}"$'\t'"${wt_path}")
        fi
    done

    local main_branch
    main_branch=$(gitmain 2> /dev/null)

    echo "Found branches with deleted upstream remotes:"
    for branch in "${del_branches[@]}"; do
        echo "  - ${branch}$(_gitcleanup-unmerged-marker "${branch}" "${main_branch}")"
    done
    for entry in "${rm_worktrees[@]}"; do
        branch="${entry%%$'\t'*}"
        echo "  - ${branch} (remove worktree ${entry#*$'\t'})$(_gitcleanup-unmerged-marker "${branch}" "${main_branch}")"
    done
    for entry in "${skipped[@]}"; do
        echo "  skipped: ${entry}"
    done

    if [ ${#del_branches[@]} -eq 0 ] && [ ${#rm_worktrees[@]} -eq 0 ]; then
        echo "No branches to clean up."
        return
    fi

    if [ "${dry_run}" = true ]; then
        echo "Dry run: no branches or worktrees were deleted."
        return
    fi

    if [ "${assume_yes}" = false ]; then
        read -r -p "Delete these branches? [y/N] " confirm_delete
    else
        confirm_delete="y"
    fi
    if [[ ! "${confirm_delete}" =~ ^[Yy]$ ]]; then
        echo "Branch deletion cancelled."
        return
    fi

    echo "Deleting branches..."
    if [ ${#del_branches[@]} -gt 0 ]; then
        git branch --delete --force "${del_branches[@]}"
    fi
    for entry in "${rm_worktrees[@]}"; do
        branch="${entry%%$'\t'*}"
        wt_path="${entry#*$'\t'}"
        if git worktree remove "${wt_path}"; then
            git branch --delete --force "${branch}"
        else
            echo "Skipped branch '${branch}': failed to remove worktree ${wt_path}"
        fi
    done
    echo "Cleanup completed."
}

gbd() {
    check-git-repo || return 1

    local all_branches=() line
    while IFS= read -r line; do
        all_branches+=("${line}")
    done < <(git branch --format='%(refname:short)')
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
    read -r -p "Select branches to delete (comma-separated numbers, e.g., 1,2,3): " branch_indices
    
    # Parse comma-separated indices
    IFS=',' read -ra indices <<< "${branch_indices}"
    local branches_to_delete=()
    local invalid_selections=()
    
    # Validate all indices and collect branch names
    for index in "${indices[@]}"; do
        # Trim whitespace
        index=$(echo "${index}" | xargs)
        
        # Check if index is valid
        if [[ ! "${index}" =~ ^[0-9]+$ ]] || [[ -z "${branches[${index}]}" ]]; then
            invalid_selections+=("${index}")
            continue
        fi
        
        local branch_name="${branches[${index}]}"
        
        # Prevent deletion of current branch
        if [ "${branch_name}" = "${current_branch}" ]; then
            echo "Warning: Cannot delete current branch '${branch_name}'. Skipping."
            continue
        fi
        
        branches_to_delete+=("${branch_name}")
    done
    
    # Check for invalid selections
    if [ ${#invalid_selections[@]} -gt 0 ]; then
        echo "Invalid selections: ${invalid_selections[*]}"
        echo "Please try again with valid branch numbers."
        return 1
    fi
    
    # Check if any branches were selected for deletion
    if [ ${#branches_to_delete[@]} -eq 0 ]; then
        echo "No valid branches selected for deletion."
        return 1
    fi
    
    # Show branches to be deleted and confirm
    echo ""
    echo "Branches selected for deletion:"
    for branch in "${branches_to_delete[@]}"; do
        echo "  - ${branch}"
    done
    echo ""
    
    read -r -p "Are you sure you want to delete these ${#branches_to_delete[@]} branch(es)? [y/N] " confirmation
    if [[ "${confirmation}" =~ ^[Yy]$ ]]; then
        echo "Deleting branches..."
        local failed_branches=()
        
        for branch in "${branches_to_delete[@]}"; do
            if git branch -d "${branch}" 2>/dev/null; then
                echo "✓ Deleted branch: ${branch}"
            else
                # Try to capture the specific error to see if it's about unmerged commits
                local error_output=$(git branch -d "${branch}" 2>&1)
                if echo "${error_output}" | grep -q "not fully merged"; then
                    echo "⚠ Branch '${branch}' is not fully merged"
                    failed_branches+=("${branch}")
                else
                    echo "✗ Failed to delete branch: ${branch}"
                    echo "  Error: ${error_output}"
                fi
            fi
        done
        
        # Handle unmerged branches
        if [ ${#failed_branches[@]} -gt 0 ]; then
            echo ""
            echo "The following branches contain unmerged commits:"
            for branch in "${failed_branches[@]}"; do
                echo "  - ${branch}"
            done
            echo ""
            read -r -p "Force delete these unmerged branches? This will permanently lose any unmerged commits! [y/N] " force_confirmation
            
            if [[ "${force_confirmation}" =~ ^[Yy]$ ]]; then
                echo "Force deleting unmerged branches..."
                for branch in "${failed_branches[@]}"; do
                    if git branch -D "${branch}"; then
                        echo "✓ Force deleted branch: ${branch}"
                    else
                        echo "✗ Failed to force delete branch: ${branch}"
                    fi
                done
            else
                echo "Unmerged branches were not deleted."
            fi
        fi
        
        echo "Branch deletion completed."
    else
        echo "Branch deletion cancelled."
    fi
}

sync-fork() {
    check-git-repo || return 1

    local main_branch
    if ! main_branch=$(gitmain); then
        echo "Failed to determine the main branch."
        return 1
    fi

    local current_branch=$(current-branch)
    local needs_branch_switch=false
    
    # Check if we need to switch branches
    if [ "${current_branch}" != "${main_branch}" ]; then
        needs_branch_switch=true
        echo "Currently on branch '${current_branch}', switching to '${main_branch}' for syncing..."
    fi

    if ! git remote get-url upstream >/dev/null 2>&1; then
        echo "Error: 'upstream' remote does not exist."
        echo "Please add it by running 'git remote add upstream https://github.com/original-repo-url.git'"
        echo "It's expected that the upstream remote points to the original repository and the forked repository is added as 'origin'."
        return 1
    fi

    # For sync-fork, we specifically want to push to origin (the fork)
    # even if upstream is the primary remote for other operations
    if ! git remote get-url origin >/dev/null 2>&1; then
        echo "Error: 'origin' remote does not exist."
        echo "For fork syncing, 'origin' should point to your fork."
        return 1
    fi

    # Switch to main branch if needed
    if [ "${needs_branch_switch}" = true ]; then
        if ! git switch "${main_branch}"; then
            echo "Failed to switch to ${main_branch} branch."
            return 1
        fi
    fi

    echo "Fetching upstream..."
    if ! git fetch upstream; then
        echo "Error: failed to fetch 'upstream'. Nothing was pushed."
        return 1
    fi

    echo "Rebasing upstream/${main_branch} onto ${main_branch}..."
    if ! git rebase "upstream/${main_branch}" "${main_branch}"; then
        echo "Error: rebase failed. Resolve conflicts, or run 'git rebase --abort' to cancel."
        return 1
    fi

    # --force-with-lease refuses the push if origin moved since our last
    # fetch, instead of silently clobbering someone else's commits.
    echo "Force pushing ${main_branch} to origin (your fork, --force-with-lease)..."
    local push_ok=true
    git push origin "${main_branch}" --force-with-lease || push_ok=false

    # Switch back to original branch if we switched away from it
    if [ "${needs_branch_switch}" = true ]; then
        echo "Switching back to original branch '${current_branch}'..."
        if ! git switch "${current_branch}"; then
            echo "Warning: Failed to switch back to '${current_branch}'. You are currently on '${main_branch}'."
            return 1
        fi
    fi

    if [ "${push_ok}" = false ]; then
        echo "Error: push refused. Origin moved since last fetch — re-fetch and retry."
        return 1
    fi
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

# Show git stats for commits on current branch
# Usage: gls (concise diff stats) or gls -v (verbose log with stats)
gls() {
    check-git-repo || return 1

    local verbose=false
    if [[ "$1" == "-v" ]]; then
        verbose=true
    fi

    local current=$(current-branch)
    local main=$(gitmain)
    
    if [ -z "${current}" ] || [ -z "${main}" ]; then
        echo "Unable to determine current or main branch."
        return 1
    fi

    if [ "${current}" = "${main}" ]; then
        echo "You are on the main branch '${main}'."
        if [ "${verbose}" = true ]; then
            read -r -p "How many commits do you want to see? " commit_count
        else
            read -r -p "How many commits do you want to diff? " commit_count
        fi
        if [[ "${commit_count}" =~ ^[0-9]+$ ]]; then
            if [ "${verbose}" = true ]; then
                git log --stat --oneline HEAD~${commit_count}..HEAD
            else
                git diff --stat HEAD~${commit_count}..HEAD
            fi
        else
            echo "Invalid number entered."
            return 1
        fi
    else
        local commit_count=$(commits-on-branch)
        if ! commits-on-branch >/dev/null; then
            echo "Error: Unable to determine the number of commits on the branch."
            return 1
        fi
        
        if [ "${commit_count}" -eq 0 ]; then
            echo "No commits found on branch '${current}' that aren't on '${main}'."
            return 0
        fi
        
        if [ "${verbose}" = true ]; then
            echo "Showing ${commit_count} commits on branch '${current}':"
            git log --stat --oneline HEAD~${commit_count}..HEAD
        else
            echo "Showing diff stats for ${commit_count} commits on branch '${current}':"
            git diff --stat HEAD~${commit_count}..HEAD
        fi
    fi
}
