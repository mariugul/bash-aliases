#!/usr/bin/env bash
# Tests for _branch-picker, the shared numbered-branch selector used by
# gsw and gbd.
#
# Usage: bash tests/test-branch-picker.sh

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
TEST_TMP="$(mktemp -d /tmp/branch-picker-tests.XXXXXX)"

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

line_number() {
    grep -nF "${1}" <<< "${2}" | head -n1 | cut -d: -f1
}

# --- Tests -----------------------------------------------------------------

test_picker_lists_main_first_then_sorted() {
    local work="${TEST_TMP}/work"
    git init --quiet --initial-branch=main "${work}"
    git -C "${work}" config user.email "test@example.com"
    git -C "${work}" config user.name "test"
    git -C "${work}" commit --quiet --allow-empty -m "initial"
    git -C "${work}" branch zeta
    git -C "${work}" branch alpha

    local out
    out=$(cd "${work}" && _branch-picker)

    local main_ln alpha_ln zeta_ln
    main_ln=$(line_number 'main' "${out}")
    alpha_ln=$(line_number 'alpha' "${out}")
    zeta_ln=$(line_number 'zeta' "${out}")

    if [ -n "${main_ln}" ] && [ -n "${alpha_ln}" ] && [ -n "${zeta_ln}" ] \
        && [ "${main_ln}" -lt "${alpha_ln}" ] \
        && [ "${alpha_ln}" -lt "${zeta_ln}" ]; then
        pass "picker lists main first, rest sorted"
    else
        fail "picker lists main first, rest sorted" "${out}"
    fi
}

test_picker_populates_array_and_numbers() {
    local work="${TEST_TMP}/work2"
    git init --quiet --initial-branch=main "${work}"
    git -C "${work}" config user.email "test@example.com"
    git -C "${work}" config user.name "test"
    git -C "${work}" commit --quiet --allow-empty -m "initial"
    git -C "${work}" branch alpha

    # Must run in the current shell for BRANCH_PICKER to persist.
    pushd "${work}" > /dev/null || return
    _branch-picker > /dev/null
    popd > /dev/null || return

    if [ "${BRANCH_PICKER[0]:-}" = "main" ] && [ "${BRANCH_PICKER[1]:-}" = "alpha" ]; then
        pass "picker fills BRANCH_PICKER matching the printed numbers"
    else
        fail "picker fills BRANCH_PICKER matching the printed numbers" \
            "0=${BRANCH_PICKER[0]:-} 1=${BRANCH_PICKER[1]:-}"
    fi
}

# --- Runner ----------------------------------------------------------------

test_picker_lists_main_first_then_sorted
test_picker_populates_array_and_numbers

echo
echo "Ran ${TESTS_RUN} tests, ${TESTS_FAILED} failed."
if [ "${TESTS_FAILED}" -gt 0 ]; then
    printf 'Failed tests:\n'
    printf '  - %s\n' "${FAILED_NAMES[@]}"
    exit 1
fi
