#!/usr/bin/env bash
# Tests for the maintenance pack (.bash_aliases.d/maintenance.sh).
#
# docker/apt-get/sudo/journalctl/ss are PATH stubs that record their
# arguments — nothing real is pruned, removed, or vacuumed. The suite can
# run on machines without any of these tools installed.
#
# Usage: bash tests/test-maintenance.sh

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
TEST_TMP="$(mktemp -d /tmp/maintenance-tests.XXXXXX)"

export HOME="${TEST_TMP}/home"
mkdir -p "${HOME}"

# Stub bin dir prepended to PATH; STUB_LOG records every invocation.
STUB_BIN="${TEST_TMP}/bin"
export STUB_LOG="${TEST_TMP}/stub.log"
mkdir -p "${STUB_BIN}"
export PATH="${STUB_BIN}:${PATH}"

# shellcheck source=../.bash_aliases.d/maintenance.sh
source "${REPO_ROOT}/.bash_aliases.d/maintenance.sh"

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

# A stub appends "name args..." to STUB_LOG and prints nothing.
make_stub() {
    cat > "${STUB_BIN}/${1}" <<'STUB'
#!/usr/bin/env bash
printf '%s %s\n' "$(basename "$0")" "$*" >> "${STUB_LOG:?}"
STUB
    chmod +x "${STUB_BIN}/${1}"
}

make_stubs() {
    local name
    for name in docker apt-get sudo journalctl ss; do
        make_stub "${name}"
    done
    : > "${STUB_LOG}"
}

stub_log() {
    cat "${STUB_LOG}" 2>/dev/null
}

# --- Tests -----------------------------------------------------------------

test_docker_clean_is_dry_run_by_default() {
    make_stubs

    local out
    out=$(docker-clean)

    if stub_log | grep -q 'docker system df' \
        && ! stub_log | grep -q 'prune' \
        && grep -qi 'dry run' <<< "${out}"; then
        pass "docker-clean defaults to a dry run (no prune)"
    else
        fail "docker-clean defaults to a dry run (no prune)" "${out} | $(stub_log)"
    fi
}

test_docker_clean_yes_prunes() {
    make_stubs

    local out
    out=$(docker-clean --yes)

    if stub_log | grep -q 'docker system prune -f'; then
        pass "docker-clean --yes runs 'docker system prune -f'"
    else
        fail "docker-clean --yes runs 'docker system prune -f'" "${out} | $(stub_log)"
    fi
}

test_apt_clean_is_dry_run_by_default() {
    make_stubs

    local out
    out=$(apt-clean)

    if stub_log | grep -q 'apt-get -s autoremove' \
        && ! stub_log | grep -q 'autoremove -y' \
        && ! stub_log | grep -q 'sudo' \
        && grep -qi 'dry run' <<< "${out}"; then
        pass "apt-clean defaults to a dry run (no sudo, no removal)"
    else
        fail "apt-clean defaults to a dry run (no sudo, no removal)" "${out} | $(stub_log)"
    fi
}

test_apt_clean_yes_removes() {
    make_stubs

    local out
    out=$(apt-clean --yes)

    if stub_log | grep -q 'sudo apt-get autoremove -y' \
        && stub_log | grep -q 'sudo apt-get clean'; then
        pass "apt-clean --yes autoremoves and clears the package cache"
    else
        fail "apt-clean --yes autoremoves and clears the package cache" "${out} | $(stub_log)"
    fi
}

test_journal_clean_is_dry_run_by_default() {
    make_stubs

    local out
    out=$(journal-clean)

    if stub_log | grep -q 'journalctl --disk-usage' \
        && ! stub_log | grep -q 'vacuum' \
        && grep -qi 'dry run' <<< "${out}"; then
        pass "journal-clean defaults to a dry run (no vacuum)"
    else
        fail "journal-clean defaults to a dry run (no vacuum)" "${out} | $(stub_log)"
    fi
}

test_journal_clean_yes_vacuums() {
    make_stubs

    local out
    out=$(journal-clean --yes 200M)

    if stub_log | grep -q 'sudo journalctl --vacuum-size=200M'; then
        pass "journal-clean --yes vacuums to the requested size"
    else
        fail "journal-clean --yes vacuums to the requested size" "${out} | $(stub_log)"
    fi
}

test_unknown_flag_fails() {
    make_stubs

    local out status
    out=$(docker-clean --bogus 2>&1) && status=0 || status=$?

    if [ "${status}" -ne 0 ] && grep -qi 'usage' <<< "${out}" \
        && ! stub_log | grep -q 'prune'; then
        pass "unknown flag fails with usage and does nothing"
    else
        fail "unknown flag fails with usage and does nothing" "status=${status} ${out} | $(stub_log)"
    fi
}

test_missing_tool_is_a_clear_error() {
    # Shadow the `command` builtin for this test so `command -v docker`
    # reports not-found even though the real docker is on PATH.
    # shellcheck disable=SC2329
    command() {
        if [ "${2:-}" = "docker" ]; then return 1; fi
        builtin command "$@"
    }

    local out status
    out=$(docker-clean --yes 2>&1) && status=0 || status=$?
    unset -f command

    if [ "${status}" -ne 0 ] && grep -qi 'docker' <<< "${out}"; then
        pass "missing docker fails with a clear error"
    else
        fail "missing docker fails with a clear error" "status=${status} ${out}"
    fi
}

test_ports_lists_listening_sockets() {
    make_stubs

    local out
    out=$(ports)

    if stub_log | grep -q '^ss '; then
        pass "ports lists listening sockets via ss"
    else
        fail "ports lists listening sockets via ss" "${out} | $(stub_log)"
    fi
}

test_disk_top_largest_first() {
    make_stubs
    local dir="${TEST_TMP}/sizes"
    mkdir -p "${dir}"
    dd if=/dev/zero of="${dir}/big.bin" bs=1024 count=16 2>/dev/null
    dd if=/dev/zero of="${dir}/small.bin" bs=1024 count=1 2>/dev/null

    local out
    out=$(disk-top "${dir}" 5)

    local big_ln small_ln
    big_ln=$(grep -n 'big.bin' <<< "${out}" | head -n1 | cut -d: -f1)
    small_ln=$(grep -n 'small.bin' <<< "${out}" | head -n1 | cut -d: -f1)
    if [ -n "${big_ln}" ] && [ -n "${small_ln}" ] && [ "${big_ln}" -lt "${small_ln}" ]; then
        pass "disk-top lists the largest entries first"
    else
        fail "disk-top lists the largest entries first" "${out}"
    fi
}

# --- Runner ----------------------------------------------------------------

test_docker_clean_is_dry_run_by_default
test_docker_clean_yes_prunes
test_apt_clean_is_dry_run_by_default
test_apt_clean_yes_removes
test_journal_clean_is_dry_run_by_default
test_journal_clean_yes_vacuums
test_unknown_flag_fails
test_missing_tool_is_a_clear_error
test_ports_lists_listening_sockets
test_disk_top_largest_first

echo
echo "Ran ${TESTS_RUN} tests, ${TESTS_FAILED} failed."
if [ "${TESTS_FAILED}" -gt 0 ]; then
    printf 'Failed tests:\n'
    printf '  - %s\n' "${FAILED_NAMES[@]}"
    exit 1
fi
