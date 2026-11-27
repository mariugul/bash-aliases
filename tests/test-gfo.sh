#!/usr/bin/env bash
# Regression tests for gfo: fetching main must work while on main, and
# while on another branch.
#
# Sandboxed: throwaway bare remote + clones under a private tmpdir with an
# isolated HOME. Usage: bash tests/test-gfo.sh

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
TEST_TMP="$(mktemp -d /tmp/gfo-tests.XXXXXX)"

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

# Create "<name>/remote.git" (bare), "<name>/work" and "<name>/other"
# clones with main pushed from work.
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
    git clone --quiet "${dir}/remote.git" "${dir}/other"
    git -C "${dir}/other" config user.email "test@example.com"
    git -C "${dir}/other" config user.name "test"
    printf '%s\n' "${dir}/work"
}

# Push a new commit to remote main from the "other" clone so local work
# is behind by one.
advance_remote_main() {
    local dir="${TEST_TMP}/${1}"
    git -C "${dir}/other" commit --quiet --allow-empty -m "upstream commit ${RANDOM}"
    git -C "${dir}/other" push --quiet origin main
}

main_tip() { git -C "${1}" rev-parse "refs/heads/main"; }
remote_tip() { git -C "${1}" rev-parse "refs/remotes/origin/main"; }

# --- Tests -----------------------------------------------------------------

test_gfo_on_main_fast_forwards() {
    local work
    work=$(make_sandbox "onmain")
    advance_remote_main "onmain"

    local out rc
    out=$(cd "${work}" && gfo 2>&1) && rc=0 || rc=$?
    if [ "${rc}" -eq 0 ] && [ "$(main_tip "${work}")" = "$(remote_tip "${work}")" ]; then
        pass "gfo fast-forwards main while on main"
    else
        fail "gfo fast-forwards main while on main" "rc=${rc} out=${out}"
    fi
}

test_gfo_off_main_updates_ref() {
    local work
    work=$(make_sandbox "offmain")
    git -C "${work}" switch --quiet -c feat
    advance_remote_main "offmain"

    local out rc
    out=$(cd "${work}" && gfo 2>&1) && rc=0 || rc=$?
    if [ "${rc}" -eq 0 ] && [ "$(main_tip "${work}")" = "$(remote_tip "${work}")" ]; then
        pass "gfo updates refs/heads/main while on another branch"
    else
        fail "gfo updates refs/heads/main while on another branch" "rc=${rc} out=${out}"
    fi
}

# --- Runner ----------------------------------------------------------------

test_gfo_on_main_fast_forwards
test_gfo_off_main_updates_ref

echo
echo "Ran ${TESTS_RUN} tests, ${TESTS_FAILED} failed."
if [ "${TESTS_FAILED}" -gt 0 ]; then
    printf 'Failed tests:\n'
    printf '  - %s\n' "${FAILED_NAMES[@]}"
    exit 1
fi
