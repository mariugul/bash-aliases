#!/usr/bin/env bash
# Regression tests for install-windows.sh profile selection: the installer
# must not create ~/.bash_profile when the user already relies on
# ~/.profile (bash sources the first existing of .bash_profile/.bash_login/
# .profile, so creating .bash_profile would silently shadow .profile).
#
# Sandboxed: HOME is a private tmpdir, curl is stubbed by a PATH shim.
# Usage: bash tests/test-install-windows.sh

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
TEST_TMP="$(mktemp -d /tmp/install-win-tests.XXXXXX)"

export HOME="${TEST_TMP}/home"
mkdir -p "${HOME}"

# Stub curl: honours -o/--combined flags, emits placeholder content.
mkdir -p "${TEST_TMP}/bin"
cat > "${TEST_TMP}/bin/curl" <<'STUB'
#!/usr/bin/env bash
arr=("$@"); n=${#arr[@]}; out=""
for ((i=0;i<n-1;i++)); do
    [[ "${arr[$i]}" == -*o ]] && out="${arr[$((i+1))]}"
done
if [ -n "${out}" ]; then printf '# downloaded\n' > "${out}"; else printf '# downloaded\n'; fi
STUB
chmod +x "${TEST_TMP}/bin/curl"
export PATH="${TEST_TMP}/bin:${PATH}"

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

run_installer() { bash "${REPO_ROOT}/install-windows.sh" </dev/null >/dev/null 2>&1; }

# --- Tests -----------------------------------------------------------------

test_existing_profile_not_shadowed() {
    rm -f "${HOME}/.bash_profile" "${HOME}/.bash_login"
    printf 'export KEEP_ME=1\n' > "${HOME}/.profile"
    run_installer
    if [ ! -f "${HOME}/.bash_profile" ] \
        && grep -q "KEEP_ME" "${HOME}/.profile" \
        && grep -q "source.*\.bash_aliases" "${HOME}/.profile"; then
        pass "existing ~/.profile is reused, ~/.bash_profile not created"
    else
        fail "existing ~/.profile is reused, ~/.bash_profile not created" \
            "$(ls -la "${HOME}"/.bash_* "${HOME}"/.profile 2>&1; cat "${HOME}"/.profile 2>/dev/null)"
    fi
}

test_no_profile_creates_bash_profile() {
    rm -f "${HOME}/.bash_profile" "${HOME}/.bash_login" "${HOME}/.profile"
    run_installer
    if [ -f "${HOME}/.bash_profile" ] \
        && grep -q "source.*\.bash_aliases" "${HOME}/.bash_profile"; then
        pass "no profile files: creates ~/.bash_profile with source block"
    else
        fail "no profile files: creates ~/.bash_profile with source block" \
            "$(ls -la "${HOME}" 2>&1)"
    fi
}

test_existing_bash_profile_used_first() {
    printf 'export KEEP_ME=1\n' > "${HOME}/.bash_profile"
    printf 'export IN_PROFILE=1\n' > "${HOME}/.profile"
    run_installer
    if grep -q "KEEP_ME" "${HOME}/.bash_profile" \
        && grep -q "source.*\.bash_aliases" "${HOME}/.bash_profile" \
        && ! grep -q "source.*\.bash_aliases" "${HOME}/.profile"; then
        pass "existing ~/.bash_profile gets the block, ~/.profile untouched"
    else
        fail "existing ~/.bash_profile gets the block, ~/.profile untouched" \
            "$(cat "${HOME}/.bash_profile"; echo ---; cat "${HOME}/.profile")"
    fi
}

test_idempotent_no_duplicate_block() {
    rm -f "${HOME}/.bash_profile" "${HOME}/.bash_login" "${HOME}/.profile"
    run_installer; run_installer
    local count
    count=$(grep -c "source.*\.bash_aliases" "${HOME}/.bash_profile")
    if [ "${count}" -eq 1 ]; then
        pass "second install does not duplicate the source block"
    else
        fail "second install does not duplicate the source block" "count=${count}"
    fi
}

# --- Runner ----------------------------------------------------------------

test_existing_profile_not_shadowed
test_no_profile_creates_bash_profile
test_existing_bash_profile_used_first
test_idempotent_no_duplicate_block

echo
echo "Ran ${TESTS_RUN} tests, ${TESTS_FAILED} failed."
if [ "${TESTS_FAILED}" -gt 0 ]; then
    printf 'Failed tests:\n'
    printf '  - %s\n' "${FAILED_NAMES[@]}"
    exit 1
fi
