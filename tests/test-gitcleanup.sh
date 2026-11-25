#!/usr/bin/env bash
# Regression tests for gitcleanup's linked-worktree handling.
#
# Every test builds a throwaway bare "remote" plus a working clone inside a
# private tmpdir with an isolated HOME. Real user repositories are never
# touched.
#
# Usage: bash tests/test-gitcleanup.sh

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
TEST_TMP="$(mktemp -d /tmp/gitcleanup-tests.XXXXXX)"

# Isolate HOME so git config and the main-branch cache stay in the sandbox.
export HOME="${TEST_TMP}/home"
mkdir -p "${HOME}"

# Functions under test.
# shellcheck source=../.bash_aliases.d/git-core.sh
source "${REPO_ROOT}/.bash_aliases.d/git-core.sh"
# shellcheck source=../.bash_aliases.d/git-workflow.sh
source "${REPO_ROOT}/.bash_aliases.d/git-workflow.sh"

trap 'rm -rf "${TEST_TMP}"' EXIT

TESTS_RUN=0
TESTS_FAILED=0
FAILED_NAMES=()

pass() {
    TESTS_RUN=$((TESTS_RUN + 1))
    printf 'PASS  %s\n' "${1}"
}

fail() {
    TESTS_RUN=$((TESTS_RUN + 1))
    TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_NAMES+=("${1}")
    printf 'FAIL  %s\n' "${1}"
    if [ -n "${2:-}" ]; then
        printf '%s\n' "${2}" | sed 's/^/      /'
    fi
}

branch_exists() {
    git -C "${1}" show-ref --verify --quiet "refs/heads/${2}"
}

worktree_registered() {
    git -C "${1}" worktree list --porcelain | grep -qF "worktree ${2}"
}

# Run gitcleanup inside the given repo dir, feeding $1 as the confirmation.
run_gitcleanup() {
    local answer="${1:-y}"
    local dir="${2}"
    (cd "${dir}" && printf '%s\n' "${answer}" | gitcleanup)
}

# Create "<name>/remote.git" (bare) and "<name>/work" with main pushed.
make_sandbox() {
    local dir="${TEST_TMP}/${1}"
    mkdir -p "${dir}"
    git init --quiet --bare --initial-branch=main "${dir}/remote.git"
    git init --quiet --initial-branch=main "${dir}/work"
    git -C "${dir}/work" config user.email "test@example.com"
    git -C "${dir}/work" config user.name "test"
    git -C "${dir}/work" commit --quiet --allow-empty -m "initial"
    git -C "${dir}/work" remote add origin "${dir}/remote.git"
    git -C "${dir}/work" push --quiet -u origin main
    printf '%s\n' "${dir}/work"
}

commit_file() {
    local repo="${1}" name="${2}"
    echo "${name} ${RANDOM}$(date +%s%N)" > "${repo}/${name}"
    git -C "${repo}" add "${name}"
    git -C "${repo}" commit --quiet -m "add ${name}"
}

# Branch off main, commit, push, then delete the remote branch. Result:
# local <branch> has a gone upstream (and unmerged commits, which is fine —
# a gone upstream alone is the cleanup criterion). Ends on main.
create_gone_branch() {
    local repo="${1}" branch="${2}"
    git -C "${repo}" switch --quiet -c "${branch}"
    commit_file "${repo}" "${branch}.txt"
    git -C "${repo}" push --quiet -u origin "${branch}"
    git -C "${repo}" switch --quiet main
    git -C "${repo}" push --quiet origin --delete "${branch}"
}

# --- Tests -----------------------------------------------------------------

test_gone_branch_deleted() {
    local work
    work=$(make_sandbox "plain")
    create_gone_branch "${work}" feat

    local out
    out=$(run_gitcleanup y "${work}" 2>&1)

    if ! branch_exists "${work}" feat && branch_exists "${work}" main; then
        pass "branch with gone upstream is deleted even when unmerged"
    else
        fail "branch with gone upstream is deleted even when unmerged" "${out}"
    fi
}

test_linked_worktree_removed_then_branch_deleted() {
    local name="linked-wt"
    local work
    work=$(make_sandbox "${name}")
    create_gone_branch "${work}" feat
    git -C "${work}" worktree add --quiet "${TEST_TMP}/${name}/wt" feat

    local out
    out=$(run_gitcleanup y "${work}" 2>&1)

    if [ ! -d "${TEST_TMP}/${name}/wt" ] \
        && ! worktree_registered "${work}" "${TEST_TMP}/${name}/wt" \
        && ! branch_exists "${work}" feat; then
        pass "clean linked worktree is removed before its branch is deleted"
    else
        fail "clean linked worktree is removed before its branch is deleted" "${out}"
    fi
}

test_worktree_path_with_spaces() {
    local name="space-wt"
    local work
    work=$(make_sandbox "${name}")
    create_gone_branch "${work}" feat
    git -C "${work}" worktree add --quiet "${TEST_TMP}/${name}/wt with space" feat

    local out
    out=$(run_gitcleanup y "${work}" 2>&1)

    if [ ! -d "${TEST_TMP}/${name}/wt with space" ] \
        && ! worktree_registered "${work}" "${TEST_TMP}/${name}/wt with space" \
        && ! branch_exists "${work}" feat; then
        pass "worktree whose path contains spaces is cleaned up"
    else
        fail "worktree whose path contains spaces is cleaned up" "${out}"
    fi
}

test_gone_branches_reports_worktree_branch() {
    local name="plus-marker"
    local work
    work=$(make_sandbox "${name}")
    create_gone_branch "${work}" feat
    git -C "${work}" worktree add --quiet "${TEST_TMP}/${name}/wt" feat
    git -C "${work}" fetch --quiet --prune origin

    local gone
    gone=$(cd "${work}" && gone-branches)

    if [[ " ${gone} " == *" feat "* ]]; then
        pass "gone-branches reports the branch of a '+'-marked worktree entry"
    else
        fail "gone-branches reports the branch of a '+'-marked worktree entry" "${gone}"
    fi
}

test_dirty_worktree_preserved() {
    local name="dirty-wt"
    local work
    work=$(make_sandbox "${name}")
    create_gone_branch "${work}" feat
    git -C "${work}" worktree add --quiet "${TEST_TMP}/${name}/wt" feat
    echo "modified" >> "${TEST_TMP}/${name}/wt/feat.txt"

    local out
    out=$(run_gitcleanup y "${work}" 2>&1)

    if [ -d "${TEST_TMP}/${name}/wt" ] \
        && worktree_registered "${work}" "${TEST_TMP}/${name}/wt" \
        && branch_exists "${work}" feat; then
        pass "dirty worktree and its branch are preserved"
    else
        fail "dirty worktree and its branch are preserved" "${out}"
    fi
}

test_untracked_worktree_preserved() {
    local name="untracked-wt"
    local work
    work=$(make_sandbox "${name}")
    create_gone_branch "${work}" feat
    git -C "${work}" worktree add --quiet "${TEST_TMP}/${name}/wt" feat
    echo "untracked" > "${TEST_TMP}/${name}/wt/scratch.txt"

    local out
    out=$(run_gitcleanup y "${work}" 2>&1)

    if [ -d "${TEST_TMP}/${name}/wt" ] \
        && worktree_registered "${work}" "${TEST_TMP}/${name}/wt" \
        && branch_exists "${work}" feat; then
        pass "worktree with untracked files and its branch are preserved"
    else
        fail "worktree with untracked files and its branch are preserved" "${out}"
    fi
}

test_locked_worktree_preserved() {
    local name="locked-wt"
    local work
    work=$(make_sandbox "${name}")
    create_gone_branch "${work}" feat
    git -C "${work}" worktree add --quiet "${TEST_TMP}/${name}/wt" feat
    git -C "${work}" worktree lock "${TEST_TMP}/${name}/wt"

    local out
    out=$(run_gitcleanup y "${work}" 2>&1)

    if [ -d "${TEST_TMP}/${name}/wt" ] \
        && worktree_registered "${work}" "${TEST_TMP}/${name}/wt" \
        && branch_exists "${work}" feat; then
        pass "locked worktree and its branch are preserved"
    else
        fail "locked worktree and its branch are preserved" "${out}"
    fi
}

test_current_worktree_protected() {
    local name="current-wt"
    local work
    work=$(make_sandbox "${name}")
    create_gone_branch "${work}" feat
    git -C "${work}" worktree add --quiet "${TEST_TMP}/${name}/wt" feat

    # Run gitcleanup from *inside* the candidate worktree.
    local out
    out=$(run_gitcleanup y "${TEST_TMP}/${name}/wt" 2>&1)

    if [ -d "${TEST_TMP}/${name}/wt" ] \
        && worktree_registered "${work}" "${TEST_TMP}/${name}/wt" \
        && branch_exists "${work}" feat; then
        pass "the worktree gitcleanup runs in is never removed"
    else
        fail "the worktree gitcleanup runs in is never removed" "${out}"
    fi
}

test_primary_worktree_protected() {
    local name="primary-wt"
    local work
    work=$(make_sandbox "${name}")
    create_gone_branch "${work}" feat
    # Check feat out in the primary worktree and run cleanup from a second
    # worktree on main.
    git -C "${work}" switch --quiet feat
    git -C "${work}" worktree add --quiet "${TEST_TMP}/${name}/main-wt" main

    local out
    out=$(run_gitcleanup y "${TEST_TMP}/${name}/main-wt" 2>&1)

    if branch_exists "${work}" feat \
        && worktree_registered "${work}" "${work}"; then
        pass "branch checked out in the primary worktree is preserved"
    else
        fail "branch checked out in the primary worktree is preserved" "${out}"
    fi
}

test_stale_worktree_registration_pruned() {
    local name="stale-wt"
    local work
    work=$(make_sandbox "${name}")
    create_gone_branch "${work}" feat
    git -C "${work}" worktree add --quiet "${TEST_TMP}/${name}/wt" feat
    # Remove the directory by hand, leaving a stale registration behind.
    rm -rf "${TEST_TMP}/${name}/wt"

    local out
    out=$(run_gitcleanup y "${work}" 2>&1)

    if ! worktree_registered "${work}" "${TEST_TMP}/${name}/wt" \
        && ! branch_exists "${work}" feat; then
        pass "stale worktree registration is pruned, branch still deleted"
    else
        fail "stale worktree registration is pruned, branch still deleted" "${out}"
    fi
}

test_mixed_candidates() {
    local name="mixed"
    local work
    work=$(make_sandbox "${name}")
    create_gone_branch "${work}" feat-plain
    create_gone_branch "${work}" feat-wt
    git -C "${work}" worktree add --quiet "${TEST_TMP}/${name}/wt" feat-wt

    local out
    out=$(run_gitcleanup y "${work}" 2>&1)

    if [ ! -d "${TEST_TMP}/${name}/wt" ] \
        && ! branch_exists "${work}" feat-plain \
        && ! branch_exists "${work}" feat-wt \
        && branch_exists "${work}" main; then
        pass "plain and worktree branches are cleaned in one run"
    else
        fail "plain and worktree branches are cleaned in one run" "${out}"
    fi
}

test_declined_confirmation_keeps_everything() {
    local name="decline"
    local work
    work=$(make_sandbox "${name}")
    create_gone_branch "${work}" feat
    git -C "${work}" worktree add --quiet "${TEST_TMP}/${name}/wt" feat

    local out
    out=$(run_gitcleanup n "${work}" 2>&1)

    if [ -d "${TEST_TMP}/${name}/wt" ] \
        && worktree_registered "${work}" "${TEST_TMP}/${name}/wt" \
        && branch_exists "${work}" feat; then
        pass "answering no at the prompt deletes nothing"
    else
        fail "answering no at the prompt deletes nothing" "${out}"
    fi
}

test_live_upstream_branch_not_candidate() {
    local work
    work=$(make_sandbox "live-upstream")
    git -C "${work}" switch --quiet -c feat
    commit_file "${work}" "feat.txt"
    git -C "${work}" push --quiet -u origin feat
    git -C "${work}" switch --quiet main

    local out
    out=$(run_gitcleanup y "${work}" 2>&1)

    if branch_exists "${work}" feat; then
        pass "branch whose upstream still exists is kept"
    else
        fail "branch whose upstream still exists is kept" "${out}"
    fi
}

# --- Runner ----------------------------------------------------------------

test_gone_branch_deleted
test_linked_worktree_removed_then_branch_deleted
test_worktree_path_with_spaces
test_gone_branches_reports_worktree_branch
test_dirty_worktree_preserved
test_untracked_worktree_preserved
test_locked_worktree_preserved
test_current_worktree_protected
test_primary_worktree_protected
test_stale_worktree_registration_pruned
test_mixed_candidates
test_declined_confirmation_keeps_everything
test_live_upstream_branch_not_candidate

echo
echo "Ran ${TESTS_RUN} tests, ${TESTS_FAILED} failed."
if [ "${TESTS_FAILED}" -gt 0 ]; then
    printf 'Failed tests:\n'
    printf '  - %s\n' "${FAILED_NAMES[@]}"
    exit 1
fi
