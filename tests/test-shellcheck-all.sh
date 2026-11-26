#!/usr/bin/env bash
# Regression tests for shellcheck-all file discovery (shellcheck.sh).
#
# Sandboxed: a fake project under a private tmpdir. Requires real shellcheck
# on PATH; skipped cleanly if absent. Usage: bash tests/test-shellcheck-all.sh

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
TEST_TMP="$(mktemp -d /tmp/sca-tests.XXXXXX)"

export HOME="${TEST_TMP}/home"
mkdir -p "${HOME}"

# shellcheck source=../.bash_aliases.d/shellcheck.sh
source "${REPO_ROOT}/.bash_aliases.d/shellcheck.sh"

trap 'rm -rf "${TEST_TMP}"' EXIT

if ! command -v shellcheck >/dev/null 2>&1; then
    echo "shellcheck not installed — skipping suite"
    exit 0
fi

TESTS_RUN=0
TESTS_FAILED=0
FAILED_NAMES=()

pass() { TESTS_RUN=$((TESTS_RUN + 1)); printf 'PASS  %s\n' "${1}"; }
fail() {
    TESTS_RUN=$((TESTS_RUN + 1)); TESTS_FAILED=$((TESTS_FAILED + 1))
    FAILED_NAMES+=("${1}"); printf 'FAIL  %s\n' "${1}"
    [ -n "${2:-}" ] && printf '%s\n' "${2}" | sed 's/^/      /'
}

PROJ="${TEST_TMP}/proj"
mkdir -p "${PROJ}/sub" "${PROJ}/tests" "${PROJ}/.git"
printf '#!/bin/bash\necho ok\n' > "${PROJ}/.bash_aliases"
printf '#!/bin/bash\necho ok\n' > "${PROJ}/foo.sh"
printf '#!/bin/bash\necho ok\n' > "${PROJ}/sub/bar.sh"
printf '#!/bin/bash\necho ok\n' > "${PROJ}/tests/test-x.sh"
printf '#!/bin/bash\necho ok\n' > "${PROJ}/.git/internal.sh"   # must be excluded

run_sca() { (cd "${PROJ}" && shellcheck-all 2>&1); }

# --- Tests -----------------------------------------------------------------

test_discovers_all_scripts() {
    local out
    out=$(run_sca)
    local checked
    checked=$(echo "${out}" | sed -nE 's/.*Files checked: ([0-9]+).*/\1/p')
    if [ "${checked}" = "4" ]; then
        pass "discovers .bash_aliases + nested .sh + tests, excludes .git"
    else
        fail "discovers .bash_aliases + nested .sh + tests, excludes .git" \
            "checked=${checked}\n${out}"
    fi
}

test_counts_issues() {
    # shellcheck disable=SC2016
    printf '#!/bin/bash\necho $undefined_var\n' > "${PROJ}/broken.sh"
    local out rc
    out=$(run_sca) && rc=0 || rc=$?
    if [ "${rc}" -ne 0 ] \
        && echo "${out}" | grep -q "broken.sh" \
        && echo "${out}" | grep -qE "Files with issues: [1-9]"; then
        pass "flags broken scripts and returns non-zero"
    else
        fail "flags broken scripts and returns non-zero" "rc=${rc}\n${out}"
    fi
    rm -f "${PROJ}/broken.sh"
}

# --- Runner ----------------------------------------------------------------

test_discovers_all_scripts
test_counts_issues

echo
echo "Ran ${TESTS_RUN} tests, ${TESTS_FAILED} failed."
if [ "${TESTS_FAILED}" -gt 0 ]; then
    printf 'Failed tests:\n'
    printf '  - %s\n' "${FAILED_NAMES[@]}"
    exit 1
fi
