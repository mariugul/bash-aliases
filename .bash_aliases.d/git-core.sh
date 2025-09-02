#!/bin/bash
# Git Core Utilities
# Foundational functions for git repository operations

# Detect the primary remote based on common conventions
# Priority: upstream > origin > first available remote
get-primary-remote() {
    check-git-repo || return 1
    
    local remotes=$(git remote)
    if [ -z "${remotes}" ]; then
        echo "No remotes found in this repository."
        return 1
    fi
    
    # Check for upstream first (common in fork scenarios)
    if echo "${remotes}" | grep -q "^upstream$"; then
        echo "upstream"
        return 0
    fi
    
    # Check for origin second (most common)
    if echo "${remotes}" | grep -q "^origin$"; then
        echo "origin"
        return 0
    fi
    
    # Fall back to first available remote
    echo "${remotes}" | head -n 1
}

current-repo() {
    local primary_remote=$(get-primary-remote)
    if ! get-primary-remote >/dev/null || [ -z "${primary_remote}" ]; then
        return 1
    fi
    git remote get-url "${primary_remote}" 2> /dev/null | sed -n 's#.*/\([^.]*\)\.git#\1#p'
}

is-git-repo() {
    git rev-parse --is-inside-work-tree > /dev/null 2>&1
}

check-git-repo() {
    if ! is-git-repo; then
        echo "Not a git repository."
        return 1
    fi
}

current-branch() {
    git branch --show-current
}

MAIN_BRANCHES_FILE="/tmp/main_branches"

# Load MAIN_BRANCHES from file if it exists
if [ -f "${MAIN_BRANCHES_FILE}" ]; then
    # shellcheck source=/dev/null
    source "${MAIN_BRANCHES_FILE}"
else
    declare -A MAIN_BRANCHES
fi

gitmain() {
    check-git-repo || return 1

    local repo=$(current-repo)
    if [ -z "${repo}" ]; then
        echo "Unable to determine repository name."
        return 1
    fi

    if [ -z "${MAIN_BRANCHES[${repo}]}" ]; then
        local primary_remote=$(get-primary-remote)
        if ! get-primary-remote >/dev/null || [ -z "${primary_remote}" ]; then
            echo "Unable to determine primary remote."
            return 1
        fi
        
        # Try to get the default branch from the remote
        local main_branch=$(git remote show "${primary_remote}" 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}')
        
        # If that fails, try common main branch names that exist locally
        if [ -z "${main_branch}" ] || [ "${main_branch}" = "(unknown)" ]; then
            for branch in main master develop; do
                if git show-ref --verify --quiet "refs/heads/${branch}"; then
                    main_branch="${branch}"
                    break
                fi
            done
        fi
        
        # If still no main branch found, default to 'main'
        if [ -z "${main_branch}" ]; then
            main_branch="main"
        fi
        
        MAIN_BRANCHES[${repo}]="${main_branch}"
        declare -p MAIN_BRANCHES > "${MAIN_BRANCHES_FILE}"
    fi
    echo "${MAIN_BRANCHES[${repo}]}"
}

commits-on-branch() {
    check-git-repo || return 1

    local current=$(current-branch)
    local main=$(gitmain)
    
    if [ -z "${current}" ] || [ -z "${main}" ]; then
        echo "Unable to determine current or main branch."
        return 1
    fi

    if [ "${current}" = "${main}" ]; then
        git rev-list --count "${main}"
    else
        # Count commits on current branch that are not on main branch
        # Use merge-base to find the common ancestor for accurate counting
        local primary_remote=$(get-primary-remote)
        if ! get-primary-remote >/dev/null || [ -z "${primary_remote}" ]; then
            local merge_base=$(git merge-base "${main}" "${current}" 2>/dev/null)
        else
            local merge_base=$(git merge-base "${primary_remote}/${main}" "${current}" 2>/dev/null)
        fi
        
        if [ -z "${merge_base}" ]; then
            git rev-list --count "${current}"
        else
            git rev-list --count "${merge_base}..${current}"
        fi
    fi
}

git-first-commit() {
    # Finds the first commit on the current branch
    check-git-repo || return 1
    git merge-base HEAD "$(gitmain)"
}

git-remotes() {
    git remote -v | awk '{print $1}' | uniq
}

gone-branches() {
    git branch -vv | awk '/\[.*\/[^:]+: gone\]/ { match($0, /\[.*\/([a-z]+\/[^:]+): gone\]/, arr); print arr[1] }' | tr '\n' ' '
}

# Returns an array: main/master at index 0 (if present), rest sorted alphabetically
sorted-branches-with-main-first() {
    local all_branches=( "$@" )
    local main_branch=""
    # Find main or master
    for b in "main" "master"; do
        for i in "${!all_branches[@]}"; do
            if [ "${all_branches[${i}]}" = "${b}" ]; then
                main_branch="${b}"
                unset 'all_branches[${i}]'
                break 2
            fi
        done
    done
    # Sort the rest
    local temp_array
    mapfile -t temp_array < <(printf "%s\n" "${all_branches[@]}" | sort)
    local sorted_branches=("${temp_array[@]}")
    unset IFS
    # Prepend main/master if found
    if [ -n "${main_branch}" ]; then
        echo "${main_branch}" "${sorted_branches[@]}"
    else
        echo "${sorted_branches[@]}"
    fi
}
