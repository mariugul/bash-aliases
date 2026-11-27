#!/usr/bin/env bash
# Tests for gitcleanup's --dry-run, --yes, and unmerged-commit markers.
#
# Same sandbox approach as test-gitcleanup.sh: throwaway bare remotes and
# clones under a private tmpdir with an isolated HOME.
#
# Usage: bash tests/test-gitcleanup-flags.sh

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
TEST_TMP="$(mktemp -d /tmp/gitcleanup-flags-tests.XXXXXX)"

export HOME="${TEST_TMP}/home"
mkdir -p "${HOME}"

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

# Branch off main, commit (unmerged), push, delete the remote branch.
create_gone_branch() {
    local repo="${1}" branch="${2}"
    git -C "${repo}" switch --quiet -c "${branch}"
    commit_file "${repo}" "${branch}.txt"
    git -C "${repo}" push --quiet -u origin "${branch}"
    git -C "${repo}" switch --quiet main
    git -C "${repo}" push --quiet origin --delete "${branch}"
}

# Branch off main, push, merge into main, delete the remote branch. The
# local branch is fully merged, so it has no unique commits.
create_merged_gone_branch() {
    local repo="${1}" branch="${2}"
    git -C "${repo}" switch --quiet -c "${branch}"
    commit_file "${repo}" "${branch}.txt"
    git -C "${repo}" push --quiet -u origin "${branch}"
    git -C "${repo}" switch --quiet main
    git -C "${repo}" merge --quiet --no-edit "${branch}"
    git -C "${repo}" push --quiet origin main
    git -C "${repo}" push --quiet origin --delete "${branch}"
}

# --- Tests -----------------------------------------------------------------

test_dry_run_deletes_nothing() {
    local work
    work=$(make_sandbox "dry-run")
    create_gone_branch "${work}" feat

    local out
    # No stdin answer: --dry-run must not prompt at all.
    out=$(cd "${work}" && gitcleanup --dry-run < /dev/null 2>&1)

    if branch_exists "${work}" feat \
        && grep -q 'feat' <<< "${out}" \
        && grep -qi 'dry' <<< "${out}"; then
        pass "--dry-run lists candidates but deletes nothing"
    else
        fail "--dry-run lists candidates but deletes nothing" "${out}"
    fi
}

test_dry_run_keeps_worktree() {
    local name="dry-run-wt"
    local work
    work=$(make_sandbox "${name}")
    create_gone_branch "${work}" feat
    git -C "${work}" worktree add --quiet "${TEST_TMP}/${name}/wt" feat

    local out
    out=$(cd "${work}" && gitcleanup --dry-run < /dev/null 2>&1)

    if [ -d "${TEST_TMP}/${name}/wt" ] && branch_exists "${work}" feat; then
        pass "--dry-run keeps worktrees and branches"
    else
        fail "--dry-run keeps worktrees and branches" "${out}"
    fi
}

test_yes_skips_prompt_and_deletes() {
    local work
    work=$(make_sandbox "yes")
    create_gone_branch "${work}" feat

    local out
    # Empty stdin: a prompt would read EOF and cancel; --yes must delete.
    out=$(cd "${work}" && gitcleanup --yes < /dev/null 2>&1)

    if ! branch_exists "${work}" feat && branch_exists "${work}" main; then
        pass "--yes deletes candidates without prompting"
    else
        fail "--yes deletes candidates without prompting" "${out}"
    fi
}

test_unmerged_marker_shown() {
    local work
    work=$(make_sandbox "marker")
    create_gone_branch "${work}" feat

    local out
    out=$(cd "${work}" && gitcleanup --dry-run < /dev/null 2>&1)

    local line
    line=$(grep -E '^\s+- feat' <<< "${out}")
    if grep -qi 'unmerged' <<< "${line}"; then
        pass "gone branch with commits not on main is marked unmerged"
    else
        fail "gone branch with commits not on main is marked unmerged" "${out}"
    fi
}

test_merged_branch_has_no_marker() {
    local work
    work=$(make_sandbox "merged")
    create_merged_gone_branch "${work}" feat

    local out
    out=$(cd "${work}" && gitcleanup --dry-run < /dev/null 2>&1)

    local line
    line=$(grep -E '^\s+- feat' <<< "${out}")
    if [ -n "${line}" ] && ! grep -qi 'unmerged' <<< "${line}"; then
        pass "fully merged gone branch has no unmerged marker"
    else
        fail "fully merged gone branch has no unmerged marker" "${out}"
    fi
}

test_unmerged_marker_on_worktree_branch() {
    local name="wt-marker"
    local work
    work=$(make_sandbox "${name}")
    create_gone_branch "${work}" feat
    git -C "${work}" worktree add --quiet "${TEST_TMP}/${name}/wt" feat

    local out
    out=$(cd "${work}" && gitcleanup --dry-run < /dev/null 2>&1)

    local line
    line=$(grep -E '^\s+- feat' <<< "${out}")
    if grep -qi 'unmerged' <<< "${line}" && grep -q 'remove worktree' <<< "${line}"; then
        pass "worktree-backed gone branch is marked unmerged"
    else
        fail "worktree-backed gone branch is marked unmerged" "${out}"
    fi
}

test_unknown_flag_fails() {
    local work
    work=$(make_sandbox "bad-flag")

    local out status
    out=$(cd "${work}" && gitcleanup --bogus < /dev/null 2>&1) && status=0 || status=$?

    if [ "${status}" -ne 0 ] && grep -qi 'usage' <<< "${out}"; then
        pass "unknown flag fails with usage"
    else
        fail "unknown flag fails with usage" "status=${status} ${out}"
    fi
}

test_no_flags_still_prompts() {
    local work
    work=$(make_sandbox "prompt")
    create_gone_branch "${work}" feat

    local out
    # Decline at the prompt: nothing should be deleted.
    out=$(cd "${work}" && printf 'n\n' | gitcleanup 2>&1)

    if branch_exists "${work}" feat && grep -qi 'cancelled' <<< "${out}"; then
        pass "no flags keeps the interactive confirmation"
    else
        fail "no flags keeps the interactive confirmation" "${out}"
    fi
}

# --- Runner ----------------------------------------------------------------

test_dry_run_deletes_nothing
test_dry_run_keeps_worktree
test_yes_skips_prompt_and_deletes
test_unmerged_marker_shown
test_merged_branch_has_no_marker
test_unmerged_marker_on_worktree_branch
test_unknown_flag_fails
test_no_flags_still_prompts

echo
echo "Ran ${TESTS_RUN} tests, ${TESTS_FAILED} failed."
if [ "${TESTS_FAILED}" -gt 0 ]; then
    printf 'Failed tests:\n'
    printf '  - %s\n' "${FAILED_NAMES[@]}"
    exit 1
fi
