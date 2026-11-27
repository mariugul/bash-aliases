#!/usr/bin/env bash
# Tests for uninstall.sh + install manifest/stale-module cleanup/append
# idempotency. Sandboxed HOME, stubbed curl. Usage: bash tests/test-uninstall.sh

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${TESTS_DIR}/.." && pwd)"
TEST_TMP="$(mktemp -d /tmp/uninstall-tests.XXXXXX)"

export HOME="${TEST_TMP}/home"
mkdir -p "${HOME}"

mkdir -p "${TEST_TMP}/bin" "${TEST_TMP}/log"
# Stub serves the REAL repo files so installs behave like the real thing.
cat > "${TEST_TMP}/bin/curl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${CURL_LOG:?}"
arr=("$@"); n=${#arr[@]}; out=""
for ((i=0;i<n-1;i++)); do
    [[ "${arr[$i]}" == -*o ]] && out="${arr[$((i+1))]}"
done
url="${arr[$((n-1))]}"
file=""
case "${url}" in
    */.bash_aliases.d/*) file="${REPO_ROOT}/.bash_aliases.d/${url##*/}" ;;
    */.bash_aliases)     file="${REPO_ROOT}/.bash_aliases" ;;
    */.shellcheckrc)     file="${REPO_ROOT}/.shellcheckrc" ;;
esac
if [ -n "${file}" ] && [ -f "${file}" ]; then content="$(cat "${file}")"; else content='# downloaded'; fi
if [ -n "${out}" ]; then printf '%s\n' "${content}" > "${out}"; else printf '%s\n' "${content}"; fi
STUB
chmod +x "${TEST_TMP}/bin/curl"
export PATH="${TEST_TMP}/bin:${PATH}"
export REPO_ROOT CURL_LOG="${TEST_TMP}/log/curl.args"
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

reset_home() { rm -rf "${HOME}"; mkdir -p "${HOME}"; }
run_installer() { (cd "${TEST_TMP}" && bash "${REPO_ROOT}/install.sh" "$@" </dev/null) >/dev/null 2>&1; }
run_uninstaller() { (cd "${TEST_TMP}" && bash "${REPO_ROOT}/uninstall.sh" "$@" </dev/null) >/dev/null 2>&1; }

# --- Tests -----------------------------------------------------------------

test_manifest_written() {
    reset_home
    run_installer
    if [ -f "${HOME}/.bash_aliases.d/.manifest" ] \
        && grep -q "git-core.sh" "${HOME}/.bash_aliases.d/.manifest"; then
        pass "install writes a module manifest"
    else
        fail "install writes a module manifest" "$(ls -la "${HOME}/.bash_aliases.d" 2>&1)"
    fi
}

test_stale_module_removed_user_file_kept() {
    reset_home
    run_installer
    # simulate a module that used to be installed but is gone from the list
    echo "stale content" > "${HOME}/.bash_aliases.d/stale-removed.sh"
    echo "stale-removed.sh" >> "${HOME}/.bash_aliases.d/.manifest"
    echo "user's own file" > "${HOME}/.bash_aliases.d/myown.sh"
    run_installer --append
    if [ ! -f "${HOME}/.bash_aliases.d/stale-removed.sh" ] \
        && [ -f "${HOME}/.bash_aliases.d/myown.sh" ]; then
        pass "manifest-tracked stale module removed, user file preserved"
    else
        fail "manifest-tracked stale module removed, user file preserved" \
            "$(ls "${HOME}/.bash_aliases.d")"
    fi
}

test_append_idempotent() {
    reset_home
    printf 'export KEEP_ME=1\n' > "${HOME}/.bashrc"
    run_installer
    run_installer --append
    run_installer --append
    local count
    count=$(grep -c "Source all modules" "${HOME}/.bash_aliases")
    if [ "${count}" -eq 1 ]; then
        pass "repeated --append does not duplicate the loader block"
    else
        fail "repeated --append does not duplicate the loader block" "count=${count}"
    fi
}

test_uninstall_removes_installed_files() {
    reset_home
    printf 'export KEEP_ME=1\n' > "${HOME}/.bashrc"
    run_installer
    run_uninstaller --yes
    if [ ! -f "${HOME}/.bash_aliases" ] \
        && [ ! -d "${HOME}/.bash_aliases.d" ] \
        && grep -q "KEEP_ME" "${HOME}/.bashrc" \
        && ! grep -q "Source bash aliases" "${HOME}/.bashrc"; then
        pass "uninstall removes installed files and strips the profile block"
    else
        fail "uninstall removes installed files and strips the profile block" \
            "$(ls -a "${HOME}"; cat "${HOME}/.bashrc")"
    fi
}

test_uninstall_backs_up_aliases() {
    reset_home
    run_installer
    echo "alias mine='echo keep'" >> "${HOME}/.bash_aliases"
    run_uninstaller --yes
    if [ -f "${HOME}/.bash_aliases.uninstall-bak" ] \
        && grep -q "alias mine=" "${HOME}/.bash_aliases.uninstall-bak"; then
        pass "uninstall backs up .bash_aliases before removing it"
    else
        fail "uninstall backs up .bash_aliases before removing it" "$(ls -a "${HOME}")"
    fi
}

test_uninstall_dry_run_changes_nothing() {
    reset_home
    run_installer
    run_uninstaller --yes --dry-run
    if [ -f "${HOME}/.bash_aliases" ] && [ -d "${HOME}/.bash_aliases.d" ]; then
        pass "--dry-run removes nothing"
    else
        fail "--dry-run removes nothing" "$(ls -a "${HOME}")"
    fi
}

test_uninstall_declined_changes_nothing() {
    reset_home
    run_installer
    run_uninstaller   # no --yes, stdin is /dev/null -> declines
    if [ -f "${HOME}/.bash_aliases" ]; then
        pass "interactive uninstall without confirmation removes nothing"
    else
        fail "interactive uninstall without confirmation removes nothing"
    fi
}

# --- Runner ----------------------------------------------------------------

test_manifest_written
test_stale_module_removed_user_file_kept
test_append_idempotent
test_uninstall_removes_installed_files
test_uninstall_backs_up_aliases
test_uninstall_dry_run_changes_nothing
test_uninstall_declined_changes_nothing

echo
echo "Ran ${TESTS_RUN} tests, ${TESTS_FAILED} failed."
if [ "${TESTS_FAILED}" -gt 0 ]; then
    printf 'Failed tests:\n'
    printf '  - %s\n' "${FAILED_NAMES[@]}"
    exit 1
fi
