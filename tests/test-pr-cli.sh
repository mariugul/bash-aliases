#!/usr/bin/env bash
# Tests for pr* command dispatch: `gh` on github.com remotes, `fj` on
# Forgejo (other) remotes, and a clear error when the CLI is missing.
#
# gh/fj are replaced by PATH stubs that record their arguments — the real
# CLIs are never invoked.
#
# Usage: bash tests/test-pr-cli.sh

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
TEST_TMP="$(mktemp -d /tmp/pr-cli-tests.XXXXXX)"

export HOME="${TEST_TMP}/home"
mkdir -p "${HOME}"

# Stub bin dir prepended to PATH; STUB_LOG records every invocation.
STUB_BIN="${TEST_TMP}/bin"
export STUB_LOG="${TEST_TMP}/stub.log"
mkdir -p "${STUB_BIN}"
export PATH="${STUB_BIN}:${PATH}"

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

# A stub appends "name args..." to STUB_LOG.
make_stub() {
    cat > "${STUB_BIN}/${1}" <<'STUB'
#!/usr/bin/env bash
printf '%s %s\n' "$(basename "$0")" "$*" >> "${STUB_LOG:?}"
STUB
    chmod +x "${STUB_BIN}/${1}"
}

# Create "<name>/work" on branch "feat" with the given remote URL.
# The remote is not contacted (URL shape only).
make_repo() {
    local dir="${TEST_TMP}/${1}"
    mkdir -p "${dir}/work"
    git init --quiet --initial-branch=main "${dir}/work"
    git -C "${dir}/work" config user.email "test@example.com"
    git -C "${dir}/work" config user.name "test"
    git -C "${dir}/work" commit --quiet --allow-empty -m "initial"
    git -C "${dir}/work" remote add origin "${2}"
    git -C "${dir}/work" switch --quiet -c feat
    printf '%s\n' "${dir}/work"
}

stub_log() {
    cat "${STUB_LOG}" 2>/dev/null
}

# --- Tests -----------------------------------------------------------------

test_prcreate_uses_gh_on_github() {
    make_stub gh; make_stub fj
    : > "${STUB_LOG}"
    local work
    work=$(make_repo "gh-remote" "https://github.com/o/r.git")

    (cd "${work}" && prcreate >/dev/null 2>&1)

    if stub_log | grep -q '^gh pr create --base main --head feat'; then
        pass "prcreate calls gh for a github.com remote"
    else
        fail "prcreate calls gh for a github.com remote" "$(stub_log)"
    fi
}

test_prcreate_uses_fj_on_forgejo() {
    make_stub gh; make_stub fj
    : > "${STUB_LOG}"
    local work
    work=$(make_repo "fj-remote" "https://git.example.com/o/r.git")

    (cd "${work}" && prcreate >/dev/null 2>&1)

    if stub_log | grep -q '^fj pr create .*--base main --head feat'; then
        pass "prcreate calls fj for a Forgejo remote"
    else
        fail "prcreate calls fj for a Forgejo remote" "$(stub_log)"
    fi
}

test_prcheckout_dispatches_to_fj() {
    make_stub gh; make_stub fj
    : > "${STUB_LOG}"
    local work
    work=$(make_repo "fj-co" "https://git.example.com/o/r.git")

    (cd "${work}" && printf '7\n' | prcheckout >/dev/null 2>&1)

    if stub_log | grep -q '^fj pr checkout 7'; then
        pass "prcheckout calls 'fj pr checkout <n>'"
    else
        fail "prcheckout calls 'fj pr checkout <n>'" "$(stub_log)"
    fi
}

test_prview_dispatches_to_fj_browse() {
    make_stub gh; make_stub fj
    : > "${STUB_LOG}"
    local work
    work=$(make_repo "fj-view" "https://git.example.com/o/r.git")

    (cd "${work}" && prview >/dev/null 2>&1)
    # prview backgrounds the browser open; give the stub a moment.
    sleep 0.3

    if stub_log | grep -q '^fj pr browse'; then
        pass "prview calls 'fj pr browse' on Forgejo"
    else
        fail "prview calls 'fj pr browse' on Forgejo" "$(stub_log)"
    fi
}

test_missing_cli_is_a_clear_error() {
    : > "${STUB_LOG}"   # no stubs on PATH
    local work
    work=$(make_repo "no-cli" "https://git.example.com/o/r.git")

    # Restrict PATH so neither the stubs nor a real fj/gh can be found.
    local out status
    out=$(cd "${work}" && PATH="/usr/bin:/bin" prcreate 2>&1) \
        && status=0 || status=$?

    if [ "${status}" -ne 0 ] && grep -qi 'fj' <<< "${out}" \
        && ! stub_log | grep -q .; then
        pass "missing fj fails with a clear error, no CLI invoked"
    else
        fail "missing fj fails with a clear error, no CLI invoked" "status=${status} ${out} $(stub_log)"
    fi
}

test_empty_checkout_number_still_rejected() {
    make_stub fj
    : > "${STUB_LOG}"
    local work
    work=$(make_repo "empty-n" "https://git.example.com/o/r.git")

    local out
    out=$(cd "${work}" && printf '\n' | prcheckout 2>&1)

    if grep -qi 'no pr number' <<< "${out}" && ! stub_log | grep -q .; then
        pass "empty PR number is rejected before calling the CLI"
    else
        fail "empty PR number is rejected before calling the CLI" "${out} $(stub_log)"
    fi
}

# --- Runner ----------------------------------------------------------------

test_prcreate_uses_gh_on_github
test_prcreate_uses_fj_on_forgejo
test_prcheckout_dispatches_to_fj
test_prview_dispatches_to_fj_browse
test_missing_cli_is_a_clear_error
test_empty_checkout_number_still_rejected

echo
echo "Ran ${TESTS_RUN} tests, ${TESTS_FAILED} failed."
if [ "${TESTS_FAILED}" -gt 0 ]; then
    printf 'Failed tests:\n'
    printf '  - %s\n' "${FAILED_NAMES[@]}"
    exit 1
fi
