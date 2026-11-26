#!/usr/bin/env bash
# Regression tests for gps: real push exit status must propagate.
#
# Sandboxed: throwaway bare remote + clone under a private tmpdir with an
# isolated HOME. Usage: bash tests/test-gps.sh

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
TEST_TMP="$(mktemp -d /tmp/gps-tests.XXXXXX)"

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

# --- Tests -----------------------------------------------------------------

test_failed_push_returns_nonzero() {
    local work
    work=$(make_sandbox "fail")
    (cd "${work}" && git switch --quiet -c feat && git commit -q --allow-empty -m x \
        && git push -q -u origin feat)
    # Kill the remote: push must fail.
    mv "${TEST_TMP}/fail/remote.git" "${TEST_TMP}/fail/remote.git.gone"

    local rc
    (cd "${work}" && gps >/dev/null 2>&1) && rc=0 || rc=$?
    if [ "${rc}" -ne 0 ]; then
        pass "failed push propagates non-zero exit status (rc=${rc})"
    else
        fail "failed push propagates non-zero exit status" "gps returned 0"
    fi
}

test_successful_push_returns_zero() {
    local work
    work=$(make_sandbox "ok")
    (cd "${work}" && git switch --quiet -c feat && git commit -q --allow-empty -m x \
        && git push -q -u origin feat && git commit -q --allow-empty -m y)

    local rc
    (cd "${work}" && gps >/dev/null 2>&1) && rc=0 || rc=$?
    if [ "${rc}" -eq 0 ]; then
        pass "successful push returns zero"
    else
        fail "successful push returns zero" "gps returned ${rc}"
    fi
}

# --- Runner ----------------------------------------------------------------

test_failed_push_returns_nonzero
test_successful_push_returns_zero

echo
echo "Ran ${TESTS_RUN} tests, ${TESTS_FAILED} failed."
if [ "${TESTS_FAILED}" -gt 0 ]; then
    printf 'Failed tests:\n'
    printf '  - %s\n' "${FAILED_NAMES[@]}"
    exit 1
fi
