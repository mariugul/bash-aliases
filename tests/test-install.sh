#!/usr/bin/env bash
# Regression tests for install.sh: profile wiring, curl --fail handling,
# and --dev anchoring to the script directory.
#
# Sandboxed: HOME is a private tmpdir, curl is a PATH shim that logs its
# arguments and can simulate an HTTP error body.
# Usage: bash tests/test-install.sh

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
TEST_TMP="$(mktemp -d /tmp/install-tests.XXXXXX)"

export HOME="${TEST_TMP}/home"
mkdir -p "${HOME}"

# Stub curl: logs args, honours -o forms, can simulate a 404 body.
mkdir -p "${TEST_TMP}/bin" "${TEST_TMP}/log"
cat > "${TEST_TMP}/bin/curl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${CURL_LOG:?}"
arr=("$@"); n=${#arr[@]}; out=""
for ((i=0;i<n-1;i++)); do
    [[ "${arr[$i]}" == -*o ]] && out="${arr[$((i+1))]}"
done
failflag=""
for a in "$@"; do
    [[ "$a" == --fail ]] && failflag=1
    [[ "$a" == -* && "$a" == *f* && "$a" != --* ]] && failflag=1
done
if [ "${FAKE_CURL_404:-0}" = "1" ]; then
    if [ -n "${failflag}" ]; then
        echo "curl: (22) The requested URL returned error: 404" >&2
        exit 22
    fi
    # simulate the bad-old-world: writes an HTML error page, exits 0
    if [ -n "${out}" ]; then printf '<html>404</html>\n' > "${out}"; else printf '<html>404</html>\n'; fi
    exit 0
fi
if [ -n "${out}" ]; then printf '# downloaded\n' > "${out}"; else printf '# downloaded\n'; fi
STUB
chmod +x "${TEST_TMP}/bin/curl"
export PATH="${TEST_TMP}/bin:${PATH}"
export CURL_LOG="${TEST_TMP}/log/curl.args"
: > "${CURL_LOG}"

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

reset_home() {
    rm -rf "${HOME}"
    mkdir -p "${HOME}"
    export FAKE_CURL_404=0
}

# shellcheck disable=SC2120
run_installer() {
    (cd "${TEST_TMP}" && bash "${REPO_ROOT}/install.sh" "$@" </dev/null) >/dev/null 2>&1
}

# --- Tests -----------------------------------------------------------------

test_bashrc_gets_source_block() {
    reset_home
    printf 'export KEEP_ME=1\n' > "${HOME}/.bashrc"
    run_installer
    if grep -q "KEEP_ME" "${HOME}/.bashrc" \
        && grep -q "source.*\.bash_aliases" "${HOME}/.bashrc"; then
        pass "existing ~/.bashrc gets .bash_aliases source block, content kept"
    else
        fail "existing ~/.bashrc gets .bash_aliases source block, content kept" \
            "$(cat "${HOME}/.bashrc" 2>/dev/null)"
    fi
}

test_profile_fallback_when_no_bashrc() {
    reset_home
    printf 'export KEEP_ME=1\n' > "${HOME}/.profile"
    run_installer
    if grep -q "source.*\.bash_aliases" "${HOME}/.profile" \
        && grep -q "KEEP_ME" "${HOME}/.profile"; then
        pass "no .bashrc: falls back to existing ~/.profile"
    else
        fail "no .bashrc: falls back to existing ~/.profile" \
            "$(ls -a "${HOME}"; cat "${HOME}/.profile" 2>/dev/null)"
    fi
}

test_source_block_idempotent() {
    reset_home
    printf 'export KEEP_ME=1\n' > "${HOME}/.bashrc"
    run_installer; run_installer
    local count
    count=$(grep -c "source.*\.bash_aliases" "${HOME}/.bashrc")
    if [ "${count}" -eq 1 ]; then
        pass "second install does not duplicate the source block"
    else
        fail "second install does not duplicate the source block" "count=${count}"
    fi
}

test_dot_source_form_detected() {
    reset_home
    # Ubuntu's stock .bashrc wires ~/.bash_aliases with the dot builtin,
    # not the "source" keyword — ensure_profile must still recognise it.
    cat > "${HOME}/.bashrc" <<'BASHRC'
# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi
BASHRC
    cp "${HOME}/.bashrc" "${TEST_TMP}/bashrc.orig"
    run_installer
    if cmp -s "${TEST_TMP}/bashrc.orig" "${HOME}/.bashrc"; then
        pass "existing '. ~/.bash_aliases' wiring detected, .bashrc untouched"
    else
        fail "existing '. ~/.bash_aliases' wiring detected, .bashrc untouched" \
            "$(diff "${TEST_TMP}/bashrc.orig" "${HOME}/.bashrc")"
    fi
}

test_curl_uses_fail_flag() {
    reset_home
    run_installer
    if grep -Eq -- '(--fail|-[^ -]*f)' "${CURL_LOG}"; then
        pass "downloads use curl --fail"
    else
        fail "downloads use curl --fail" "$(cat "${CURL_LOG}")"
    fi
}

test_404_does_not_poison_bash_aliases() {
    reset_home
    export FAKE_CURL_404=1
    run_installer
    if [ -f "${HOME}/.bash_aliases" ] && grep -q "<html>" "${HOME}/.bash_aliases"; then
        fail "HTTP 404 body is not written into ~/.bash_aliases" "HTML was installed"
    else
        pass "HTTP 404 body is not written into ~/.bash_aliases"
    fi
}

test_dev_anchors_to_script_dir() {
    reset_home
    # --dev must work when invoked from a directory that is NOT the repo
    (cd "${TEST_TMP}" && bash "${REPO_ROOT}/install.sh" --dev </dev/null) >/dev/null 2>&1
    if [ -f "${HOME}/.bash_aliases" ] \
        && grep -q "Source all modules" "${HOME}/.bash_aliases" \
        && [ -f "${HOME}/.bash_aliases.d/git-core.sh" ]; then
        pass "--dev installs local files regardless of CWD"
    else
        fail "--dev installs local files regardless of CWD" \
            "$(ls -a "${HOME}" "${HOME}/.bash_aliases.d" 2>/dev/null)"
    fi
}

# --- Runner ----------------------------------------------------------------

test_bashrc_gets_source_block
test_profile_fallback_when_no_bashrc
test_source_block_idempotent
test_dot_source_form_detected
test_curl_uses_fail_flag
test_404_does_not_poison_bash_aliases
test_dev_anchors_to_script_dir

echo
echo "Ran ${TESTS_RUN} tests, ${TESTS_FAILED} failed."
if [ "${TESTS_FAILED}" -gt 0 ]; then
    printf 'Failed tests:\n'
    printf '  - %s\n' "${FAILED_NAMES[@]}"
    exit 1
fi
