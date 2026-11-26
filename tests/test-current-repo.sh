#!/usr/bin/env bash
# Regression tests for current-repo URL parsing (git-core.sh).
#
# Sandboxed: repos and remotes are throwaway dirs under a private tmpdir
# with an isolated HOME. Usage: bash tests/test-current-repo.sh

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
TEST_TMP="$(mktemp -d /tmp/current-repo-tests.XXXXXX)"

export HOME="${TEST_TMP}/home"
mkdir -p "${HOME}"

# shellcheck source=../.bash_aliases.d/git-core.sh
source "${REPO_ROOT}/.bash_aliases.d/git-core.sh"

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

check_url() {
    # $1 = remote URL, $2 = expected owner/repo
    local n="${TEST_TMP}/r${TESTS_RUN}"
    git init --quiet "${n}"
    git -C "${n}" remote add origin "${1}"
    local got
    got=$(cd "${n}" && current-repo)
    if [ "${got}" = "${2}" ]; then
        pass "url '${1}' -> '${2}'"
    else
        fail "url '${1}' -> '${2}'" "got '${got}'"
    fi
}

# --- Tests -----------------------------------------------------------------

check_url "https://git.anaogmarius.eu/Marius/bash-aliases.git" "Marius/bash-aliases"
check_url "https://git.anaogmarius.eu/Marius/bash-aliases" "Marius/bash-aliases"
check_url "git@git.anaogmarius.eu:Marius/bash-aliases.git" "Marius/bash-aliases"
check_url "ssh://git@git.anaogmarius.eu/Marius/bash-aliases.git" "Marius/bash-aliases"
check_url "https://git.anaogmarius.eu/Marius/my.repo.git" "Marius/my.repo"
check_url "https://git.anaogmarius.eu/Marius/my.repo" "Marius/my.repo"
check_url "git@github.com:owner/repo.name.with.dots.git" "owner/repo.name.with.dots"
check_url "https://github.com/owner/sub/dir/repo.git" "dir/repo"

echo
echo "Ran ${TESTS_RUN} tests, ${TESTS_FAILED} failed."
if [ "${TESTS_FAILED}" -gt 0 ]; then
    printf 'Failed tests:\n'
    printf '  - %s\n' "${FAILED_NAMES[@]}"
    exit 1
fi
