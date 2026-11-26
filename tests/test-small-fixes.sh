#!/usr/bin/env bash
# Regression tests for the small-fixes bundle: IFS leak, gitcleanup remote
# count, stdout/stderr routing, and check-and-pull detection.
#
# Sandboxed: throwaway repos under a private tmpdir with isolated HOME.
# Usage: bash tests/test-small-fixes.sh

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
TEST_TMP="$(mktemp -d /tmp/small-fixes-tests.XXXXXX)"

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

pass() { TESTS_RUN=$((TESTS_RUN + 1)); printf 'PASS  %s\n' "${1}"; }
fail() {
    TESTS_RUN=$((TESTS_RUN + 1)); TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_NAMES+=("${1}"); printf 'FAIL  %s\n' "${1}"
    [ -n "${2:-}" ] && printf '%s\n' "${2}" | sed 's/^/      /'
}

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

# --- Tests -----------------------------------------------------------------

test_ifs_preserved() {
    local IFS='XYZ'
    sorted-branches-with-main-first beta main alpha >/dev/null
    if [ "${IFS}" = 'XYZ' ]; then
        pass "sorted-branches-with-main-first does not clobber IFS"
    else
        fail "sorted-branches-with-main-first does not clobber IFS" "IFS='${IFS}'"
    fi
}

test_sorted_branches_order() {
    local got
    got=$(sorted-branches-with-main-first zebra beta main alpha)
    if [ "${got}" = "main alpha beta zebra" ]; then
        pass "main sorts first, rest alphabetical"
    else
        fail "main sorts first, rest alphabetical" "got '${got}'"
    fi
}

test_gitcleanup_zero_remotes() {
    local dir="${TEST_TMP}/norem"
    git init --quiet --initial-branch=main "${dir}"
    git -C "${dir}" config user.email t@t; git -C "${dir}" config user.name t
    git -C "${dir}" commit -q --allow-empty -m init
    local out
    out=$(cd "${dir}" && gitcleanup 2>&1 | head -1)
    if [[ "${out}" == *"0 remote"* ]]; then
        pass "gitcleanup reports 0 remotes correctly"
    else
        fail "gitcleanup reports 0 remotes correctly" "got '${out}'"
    fi
}

test_check_git_repo_stderr() {
    local dir="${TEST_TMP}/plain" out
    mkdir -p "${dir}"
    out=$(cd "${dir}" && check-git-repo 2>/dev/null)
    if [ -z "${out}" ]; then
        pass "check-git-repo writes errors to stderr, not stdout"
    else
        fail "check-git-repo writes errors to stderr, not stdout" "stdout='${out}'"
    fi
}

test_gitmain_stderr_outside_repo() {
    local dir="${TEST_TMP}/plain2" out
    mkdir -p "${dir}"
    out=$(cd "${dir}" && gitmain 2>/dev/null)
    if [ -z "${out}" ]; then
        pass "gitmain writes errors to stderr, not stdout"
    else
        fail "gitmain writes errors to stderr, not stdout" "stdout='${out}'"
    fi
}

test_check_and_pull_behind() {
    local work
    work=$(make_sandbox "behind")
    # advance remote via a second clone so work is behind by 1
    git clone --quiet "${TEST_TMP}/behind/remote.git" "${TEST_TMP}/behind/other"
    git -C "${TEST_TMP}/behind/other" config user.email t@t
    git -C "${TEST_TMP}/behind/other" config user.name t
    git -C "${TEST_TMP}/behind/other" commit -q --allow-empty -m "upstream1"
    git -C "${TEST_TMP}/behind/other" push -q origin main
    git -C "${work}" fetch -q origin

    local out
    out=$(cd "${work}" && printf 'n\n' | check-and-pull "" false 2>&1)
    if [[ "${out}" == *"behind"* && "${out}" == *"1"* ]]; then
        pass "check-and-pull detects behind-by-N and prompts"
    else
        fail "check-and-pull detects behind-by-N and prompts" "got '${out}'"
    fi
}

test_check_and_pull_diverged() {
    local work
    work=$(make_sandbox "diverged")
    git clone --quiet "${TEST_TMP}/diverged/remote.git" "${TEST_TMP}/diverged/other"
    git -C "${TEST_TMP}/diverged/other" config user.email t@t
    git -C "${TEST_TMP}/diverged/other" config user.name t
    git -C "${TEST_TMP}/diverged/other" commit -q --allow-empty -m "upstream1"
    git -C "${TEST_TMP}/diverged/other" push -q origin main
    git -C "${work}" commit -q --allow-empty -m "local1"
    git -C "${work}" fetch -q origin

    local out
    out=$(cd "${work}" && printf 'n\n' | check-and-pull "" false 2>&1)
    if [[ "${out}" == *"diverged"* ]]; then
        pass "check-and-pull reports diverged state"
    else
        fail "check-and-pull reports diverged state" "got '${out}'"
    fi
}

test_check_and_pull_no_upstream_quiet() {
    local dir="${TEST_TMP}/noups" out
    git init --quiet --initial-branch=main "${dir}"
    git -C "${dir}" config user.email t@t; git -C "${dir}" config user.name t
    git -C "${dir}" commit -q --allow-empty -m init
    out=$(cd "${dir}" && check-and-pull "" false 2>&1)
    if [ -z "${out}" ]; then
        pass "check-and-pull is quiet when no upstream exists"
    else
        fail "check-and-pull is quiet when no upstream exists" "got '${out}'"
    fi
}

# --- Runner ----------------------------------------------------------------

test_ifs_preserved
test_sorted_branches_order
test_gitcleanup_zero_remotes
test_check_git_repo_stderr
test_gitmain_stderr_outside_repo
test_check_and_pull_behind
test_check_and_pull_diverged
test_check_and_pull_no_upstream_quiet

echo
echo "Ran ${TESTS_RUN} tests, ${TESTS_FAILED} failed."
if [ "${TESTS_FAILED}" -gt 0 ]; then
    printf 'Failed tests:\n'
    printf '  - %s\n' "${FAILED_NAMES[@]}"
    exit 1
fi
