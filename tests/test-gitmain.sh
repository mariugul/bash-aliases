#!/usr/bin/env bash
# Regression tests for gitmain: correct detection, flat-file cache format,
# refresh semantics, set -u safety. Runs under bash 3.2-compatible code.
#
# Sandboxed repos + isolated HOME. Usage: bash tests/test-gitmain.sh

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
TEST_TMP="$(mktemp -d /tmp/gitmain-tests.XXXXXX)"

export HOME="${TEST_TMP}/home"
mkdir -p "${HOME}"

# shellcheck source=../.bash_aliases.d/git-core.sh
source "${REPO_ROOT}/.bash_aliases.d/git-core.sh"

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

make_repo() {
    # $1=name $2=default-branch
    local dir="${TEST_TMP}/${1}"
    mkdir -p "${dir}"
    git init --quiet --bare --initial-branch="${2}" "${dir}/remote.git"
    git init --quiet --initial-branch="${2}" "${dir}/work"
    git -C "${dir}/work" config user.email t@t; git -C "${dir}/work" config user.name t
    git -C "${dir}/work" commit -q --allow-empty -m init
    git -C "${dir}/work" remote add origin "${dir}/remote.git"
    git -C "${dir}/work" push -q -u origin "${2}"
    printf '%s\n' "${dir}/work"
}

CACHE="${HOME}/.cache/bash-aliases/main_branches"

# --- Tests -----------------------------------------------------------------

test_detects_main() {
    local work got
    work=$(make_repo "m" main)
    got=$(cd "${work}" && gitmain)
    if [ "${got}" = "main" ]; then
        pass "detects 'main' as default branch"
    else
        fail "detects 'main' as default branch" "got '${got}'"
    fi
}

test_detects_master() {
    local work got
    work=$(make_repo "master" master)
    got=$(cd "${work}" && gitmain)
    if [ "${got}" = "master" ]; then
        pass "detects 'master' as default branch"
    else
        fail "detects 'master' as default branch" "got '${got}'"
    fi
}

test_cache_written_flat_format() {
    local work
    work=$(make_repo "cached" main)
    (cd "${work}" && gitmain >/dev/null)
    # flat 'repo=branch' lines; must NOT be 'declare -A' output
    if [ -f "${CACHE}" ] && grep -q "=" "${CACHE}" \
        && ! grep -q "declare -A" "${CACHE}" \
        && bash -n "${CACHE}"; then
        pass "cache file uses flat repo=branch format"
    else
        fail "cache file uses flat repo=branch format" "$(cat "${CACHE}" 2>/dev/null)"
    fi
}

test_refresh_recovers_repo() {
    local work
    work=$(make_repo "ref" main)
    (cd "${work}" && gitmain >/dev/null)
    (cd "${work}" && gitmain --refresh >/dev/null)
    if [ -f "${CACHE}" ] && grep -q "=" "${CACHE}"; then
        pass "--refresh re-caches the repo entry"
    else
        fail "--refresh re-caches the repo entry" "$(cat "${CACHE}" 2>/dev/null)"
    fi
}

test_refresh_all_clears() {
    local w1 w2
    w1=$(make_repo "ra1" main); w2=$(make_repo "ra2" main)
    (cd "${w1}" && gitmain >/dev/null); (cd "${w2}" && gitmain >/dev/null)
    (cd "${w1}" && gitmain --refresh-all >/dev/null)
    # after refresh-all, only the calling repo re-caches
    if [ "$(wc -l < "${CACHE}")" -le 1 ]; then
        pass "--refresh-all clears all cached entries"
    else
        fail "--refresh-all clears all cached entries" "$(cat "${CACHE}")"
    fi
}

test_gitmain_under_set_u() {
    local work rc
    work=$(make_repo "setu" main)
    rc=$(cd "${work}" && bash -u -c 'source "'"${REPO_ROOT}"'/.bash_aliases.d/git-core.sh"; gitmain' 2>&1) || true
    if [ "${rc}" = "main" ]; then
        pass "gitmain works under set -u"
    else
        fail "gitmain works under set -u" "got '${rc}'"
    fi
}

# --- Runner ----------------------------------------------------------------

test_detects_main
test_detects_master
test_cache_written_flat_format
test_refresh_recovers_repo
test_refresh_all_clears
test_gitmain_under_set_u

echo
echo "Ran ${TESTS_RUN} tests, ${TESTS_FAILED} failed."
if [ "${TESTS_FAILED}" -gt 0 ]; then
    printf 'Failed tests:\n'
    printf '  - %s\n' "${FAILED_NAMES[@]}"
    exit 1
fi
