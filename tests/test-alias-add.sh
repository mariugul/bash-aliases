#!/usr/bin/env bash
# Regression tests for alias-add (system.sh): quoting, duplicate detection,
# name validation, and that the file stays valid bash.
#
# Sandboxed: HOME is redirected into a private tmpdir. Usage:
#   bash tests/test-alias-add.sh

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
TEST_TMP="$(mktemp -d /tmp/alias-add-tests.XXXXXX)"

export HOME="${TEST_TMP}/home"
mkdir -p "${HOME}"
: > "${HOME}/.bash_aliases"

# shellcheck source=../.bash_aliases.d/system.sh
source "${REPO_ROOT}/.bash_aliases.d/system.sh"

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

file_is_valid_bash() {
    bash -n "${HOME}/.bash_aliases"
}

reset_file() { : > "${HOME}/.bash_aliases"; }

# --- Tests -----------------------------------------------------------------

test_single_quote_command() {
    reset_file
    alias-add mytest "it's broken" >/dev/null 2>&1
    if file_is_valid_bash && grep -q "alias mytest=" "${HOME}/.bash_aliases"; then
        pass "command containing a single quote keeps file valid"
    else
        fail "command containing a single quote keeps file valid" "$(cat "${HOME}/.bash_aliases")"
    fi
}

test_quoted_alias_usable() {
    reset_file
    alias-add greet 'echo hello' >/dev/null 2>&1
    local got
    # eval re-parses after expand_aliases is enabled so the alias expands
    got=$(bash -c "source '${HOME}/.bash_aliases'; shopt -s expand_aliases; eval greet" 2>/dev/null)
    if [ "${got}" = "hello" ]; then
        pass "added alias actually works when sourced"
    else
        fail "added alias actually works when sourced" "got: ${got}"
    fi
}

test_regex_name_not_false_positive() {
    reset_file
    echo "alias gax='echo existing'" > "${HOME}/.bash_aliases"
    alias-add g.x 'echo dotted' >/dev/null 2>&1
    if grep -q "alias g\.x=" "${HOME}/.bash_aliases"; then
        pass "dotted name is not rejected by a regex dup-check false positive"
    else
        fail "dotted name is not rejected by a regex dup-check false positive" "$(cat "${HOME}/.bash_aliases")"
    fi
}

test_true_duplicate_detected() {
    reset_file
    echo "alias dup='echo one'" > "${HOME}/.bash_aliases"
    local out
    out=$(alias-add dup 'echo two' 2>&1)
    if echo "${out}" | grep -qi "already exists" && [ "$(grep -c 'alias dup=' "${HOME}/.bash_aliases")" -eq 1 ]; then
        pass "real duplicate is detected and not appended"
    else
        fail "real duplicate is detected and not appended" "${out}"
    fi
}

test_invalid_name_rejected() {
    reset_file
    if alias-add 'bad;name' 'echo hi' >/dev/null 2>&1 \
        || alias-add 'bad name' 'echo hi' >/dev/null 2>&1; then
        fail "invalid alias names are rejected" "accepted a bad name"
    else
        pass "invalid alias names are rejected"
    fi
}

test_missing_args_usage() {
    reset_file
    local out rc
    out=$(alias-add 2>&1) && rc=0 || rc=$?
    if [ "${rc}" -ne 0 ] && echo "${out}" | grep -qi usage; then
        pass "missing arguments prints usage and fails"
    else
        fail "missing arguments prints usage and fails" "${out}"
    fi
}

# --- Runner ----------------------------------------------------------------

test_single_quote_command
test_quoted_alias_usable
test_regex_name_not_false_positive
test_true_duplicate_detected
test_invalid_name_rejected
test_missing_args_usage

echo
echo "Ran ${TESTS_RUN} tests, ${TESTS_FAILED} failed."
if [ "${TESTS_FAILED}" -gt 0 ]; then
    printf 'Failed tests:\n'
    printf '  - %s\n' "${FAILED_NAMES[@]}"
    exit 1
fi
