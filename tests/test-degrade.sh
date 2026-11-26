#!/usr/bin/env bash
# Regression tests for graceful degradation: sourcing ~/.bash_aliases must
# not explode with 'command not found' when modules are missing or partial.
#
# Sandboxed: fake HOME with copies of the repo's .bash_aliases.
# Usage: bash tests/test-degrade.sh

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
TEST_TMP="$(mktemp -d /tmp/degrade-tests.XXXXXX)"

export HOME="${TEST_TMP}/home"
mkdir -p "${HOME}"
cp "${REPO_ROOT}/.bash_aliases" "${HOME}/.bash_aliases"

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

source_aliases() {
    (cd "${TEST_TMP}" && bash -c 'source ~/.bash_aliases' 2>&1)
}

# --- Tests -----------------------------------------------------------------

test_no_modules_no_command_not_found() {
    rm -rf "${HOME}/.bash_aliases.d"
    local out
    out=$(source_aliases)
    if ! echo "${out}" | grep -q "command not found"; then
        pass "no .bash_aliases.d: no 'command not found' errors"
    else
        fail "no .bash_aliases.d: no 'command not found' errors" "${out}"
    fi
}

test_missing_modules_warns_once() {
    rm -rf "${HOME}/.bash_aliases.d"
    local out
    out=$(source_aliases)
    if echo "${out}" | grep -qi "bash-aliases\|install\|module"; then
        pass "missing modules produces a helpful warning"
    else
        fail "missing modules produces a helpful warning" "out='${out}'"
    fi
}

test_show_help_works_without_modules() {
    rm -rf "${HOME}/.bash_aliases.d"
    local out rc
    out=$(cd "${TEST_TMP}" && bash -c 'source ~/.bash_aliases; show-help' 2>/dev/null) && rc=0 || rc=$?
    if [ "${rc}" -eq 0 ] && echo "${out}" | grep -q "Available Commands"; then
        pass "show-help still runs when modules are missing"
    else
        fail "show-help still runs when modules are missing" "rc=${rc} out='${out}'"
    fi
}

test_partial_modules_no_noise() {
    mkdir -p "${HOME}/.bash_aliases.d"
    cp "${REPO_ROOT}/.bash_aliases.d/text.sh" "${HOME}/.bash_aliases.d/"
    cp "${REPO_ROOT}/.bash_aliases.d/system.sh" "${HOME}/.bash_aliases.d/"
    local out
    out=$(source_aliases)
    if ! echo "${out}" | grep -q "command not found"; then
        pass "partial module set: no 'command not found' errors"
    else
        fail "partial module set: no 'command not found' errors" "${out}"
    fi
}

test_full_modules_clean_startup() {
    rm -rf "${HOME}/.bash_aliases.d"
    mkdir -p "${HOME}/.bash_aliases.d"
    cp "${REPO_ROOT}/.bash_aliases.d/"*.sh "${HOME}/.bash_aliases.d/"
    local out
    out=$(source_aliases)
    if ! echo "${out}" | grep -qiE "command not found|bash-aliases:"; then
        pass "full module set: clean startup, no warnings"
    else
        fail "full module set: clean startup, no warnings" "${out}"
    fi
}

# --- Runner ----------------------------------------------------------------

test_no_modules_no_command_not_found
test_missing_modules_warns_once
test_show_help_works_without_modules
test_partial_modules_no_noise
test_full_modules_clean_startup

echo
echo "Ran ${TESTS_RUN} tests, ${TESTS_FAILED} failed."
if [ "${TESTS_FAILED}" -gt 0 ]; then
    printf 'Failed tests:\n'
    printf '  - %s\n' "${FAILED_NAMES[@]}"
    exit 1
fi
