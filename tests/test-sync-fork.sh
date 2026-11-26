#!/usr/bin/env bash
# Regression tests for sync-fork: fetch failures, --force-with-lease
# semantics, and branch restoration.
#
# Sandboxed: all remotes are bare repos under a private tmpdir with an
# isolated HOME. Usage: bash tests/test-sync-fork.sh

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
TEST_TMP="$(mktemp -d /tmp/sync-fork-tests.XXXXXX)"

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

# Create "<name>/{upstream.git,origin.git}" (bare) and "<name>/work"
# cloned from origin with an upstream remote — a fork topology.
make_sandbox() {
    local dir="${TEST_TMP}/${1}"
    mkdir -p "${dir}"
    git init --quiet --bare --initial-branch=main "${dir}/upstream.git"
    git init --quiet --bare --initial-branch=main "${dir}/origin.git"
    # seed repo puts identical history on both remotes
    git init --quiet --initial-branch=main "${dir}/seed"
    git -C "${dir}/seed" config user.email "test@example.com"
    git -C "${dir}/seed" config user.name "test"
    git -C "${dir}/seed" commit --quiet --allow-empty -m "initial"
    git -C "${dir}/seed" push --quiet "${dir}/upstream.git" main
    git -C "${dir}/seed" push --quiet "${dir}/origin.git" main
    git clone --quiet "${dir}/origin.git" "${dir}/work"
    git -C "${dir}/work" config user.email "test@example.com"
    git -C "${dir}/work" config user.name "test"
    git -C "${dir}/work" remote add upstream "${dir}/upstream.git"
    printf '%s\n' "${dir}/work"
}

advance_upstream() {
    local dir="${TEST_TMP}/${1}"
    git -C "${dir}/seed" commit --quiet --allow-empty -m "upstream ${RANDOM}"
    git -C "${dir}/seed" push --quiet "${dir}/upstream.git" main
}

# --- Tests -----------------------------------------------------------------

test_syncs_main_to_origin() {
    local work
    work=$(make_sandbox "sync")
    advance_upstream "sync"

    local out rc
    out=$(cd "${work}" && sync-fork 2>&1) && rc=0 || rc=$?
    local upstream_tip origin_tip
    upstream_tip=$(git -C "${TEST_TMP}/sync/upstream.git" rev-parse refs/heads/main)
    origin_tip=$(git -C "${TEST_TMP}/sync/origin.git" rev-parse refs/heads/main)
    if [ "${rc}" -eq 0 ] && [ "${upstream_tip}" = "${origin_tip}" ]; then
        pass "sync-fork rebases main onto upstream and pushes to origin"
    else
        fail "sync-fork rebases main onto upstream and pushes to origin" "rc=${rc} out=${out}"
    fi
}

test_failed_upstream_fetch_returns_error() {
    local work
    work=$(make_sandbox "deadup")
    rm -rf "${TEST_TMP}/deadup/upstream.git"   # kill the upstream remote

    local out rc origin_before origin_after
    origin_before=$(git -C "${TEST_TMP}/deadup/origin.git" rev-parse refs/heads/main)
    out=$(cd "${work}" && sync-fork 2>&1) && rc=0 || rc=$?
    origin_after=$(git -C "${TEST_TMP}/deadup/origin.git" rev-parse refs/heads/main)
    if [ "${rc}" -ne 0 ] && [ "${origin_before}" = "${origin_after}" ]; then
        pass "failed upstream fetch returns error and pushes nothing"
    else
        fail "failed upstream fetch returns error and pushes nothing" "rc=${rc} out=${out}"
    fi
}

test_lease_rejects_when_remote_moved() {
    local work
    work=$(make_sandbox "lease")
    advance_upstream "lease"
    # origin remote-tracking ref is stale: advance origin behind our back
    # without fetching in work. --force-with-lease must REFUSE the push;
    # --force would clobber the conflicting commit.
    local conflict_tip
    conflict_tip=$(git -C "${TEST_TMP}/lease/seed" rev-parse HEAD)
    git -C "${TEST_TMP}/lease/seed" commit --quiet --allow-empty -m "conflict on origin"
    conflict_tip=$(git -C "${TEST_TMP}/lease/seed" rev-parse HEAD)
    git -C "${TEST_TMP}/lease/seed" push --quiet "${TEST_TMP}/lease/origin.git" main

    local out rc
    out=$(cd "${work}" && sync-fork 2>&1) && rc=0 || rc=$?
    local origin_tip
    origin_tip=$(git -C "${TEST_TMP}/lease/origin.git" rev-parse refs/heads/main)
    if [ "${rc}" -ne 0 ] && [ "${origin_tip}" = "${conflict_tip}" ]; then
        pass "stale remote-tracking ref: push refused, origin kept conflicting commit"
    else
        fail "stale remote-tracking ref: push refused, origin kept conflicting commit" \
            "rc=${rc} out=${out}"
    fi
}

test_returns_to_original_branch() {
    local work
    work=$(make_sandbox "branch")
    git -C "${work}" switch --quiet -c feat
    git -C "${work}" commit --quiet --allow-empty -m "feat work"
    advance_upstream "branch"

    (cd "${work}" && sync-fork >/dev/null 2>&1)
    local cur
    cur=$(git -C "${work}" branch --show-current)
    if [ "${cur}" = "feat" ]; then
        pass "returns to the original branch after syncing"
    else
        fail "returns to the original branch after syncing" "on ${cur}"
    fi
}

# --- Runner ----------------------------------------------------------------

test_syncs_main_to_origin
test_failed_upstream_fetch_returns_error
test_lease_rejects_when_remote_moved
test_returns_to_original_branch

echo
echo "Ran ${TESTS_RUN} tests, ${TESTS_FAILED} failed."
if [ "${TESTS_FAILED}" -gt 0 ]; then
    printf 'Failed tests:\n'
    printf '  - %s\n' "${FAILED_NAMES[@]}"
    exit 1
fi
