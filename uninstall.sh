#!/bin/bash

# Bash Aliases Uninstaller
# Removes what install.sh installed:
#   - ~/.bash_aliases (backed up to ~/.bash_aliases.uninstall-bak first)
#   - ~/.bash_aliases.d/ modules (manifest-tracked; user files preserved)
#   - the "# Source bash aliases" block appended to the user's profile
#   - ~/.cache/bash-aliases/
#
# ~/.bash_aliases.bak and ~/.shellcheckrc are left alone — the backup may be
# wanted, and .shellcheckrc may predate or be shared with other tools.
#
# Options:
#   --yes, -y     Skip the confirmation prompt
#   --dry-run     Show what would be removed without touching anything
#   --help, -h    Show this help

set -e

TARGET="${HOME}/.bash_aliases"
TARGET_DIR="${HOME}/.bash_aliases.d"
MANIFEST="${TARGET_DIR}/.manifest"
CACHE_DIR="${HOME}/.cache/bash-aliases"
BACKUP="${TARGET}.uninstall-bak"

PROFILE_CANDIDATES=("${HOME}/.bashrc" "${HOME}/.bash_profile" "${HOME}/.bash_login" "${HOME}/.profile")

yes=false
dry_run=false
for arg in "${@}"; do
    case "${arg}" in
        --help|-h)
            sed -n '2,20p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        --yes|-y)  yes=true ;;
        --dry-run) dry_run=true ;;
        *)
            echo "Unknown option: ${arg}" >&2
            echo "Use --help for usage information." >&2
            exit 1
            ;;
    esac
done

say() {
    if [ "${dry_run}" = true ]; then
        echo "  [dry-run] $*"
    else
        echo "  $*"
    fi
}

# Remove the "# Source bash aliases" block we appended to a profile file.
strip_profile_block() {
    local file="${1}"
    [ -f "${file}" ] || return 0
    grep -q "Source bash aliases" "${file}" || return 0
    if [ "${dry_run}" = true ]; then
        say "would remove source block from ${file}"
        return 0
    fi
    awk '
        /^# Source bash aliases$/ { skip = 1; next }
        skip && /^fi$/ { skip = 0; next }
        !skip { print }
    ' "${file}" > "${file}.tmp" && mv "${file}.tmp" "${file}"
    say "removed source block from ${file}"
}

remove_file() {
    local file="${1}"
    if [ -e "${file}" ]; then
        if [ "${dry_run}" = true ]; then
            say "would remove ${file}"
        else
            rm -f "${file}"
            say "removed ${file}"
        fi
    fi
}

remove_dir() {
    local dir="${1}"
    if [ -d "${dir}" ]; then
        if [ "${dry_run}" = true ]; then
            say "would remove ${dir}/"
        else
            rm -rf "${dir}"
            say "removed ${dir}/"
        fi
    fi
}

echo "Bash aliases uninstaller"
echo ""

# Collect what will change
declare -a plan=()
[ -f "${TARGET}" ] && plan+=("${TARGET}")
[ -d "${TARGET_DIR}" ] && plan+=("${TARGET_DIR}/ (manifest-tracked files only)")
[ -d "${CACHE_DIR}" ] && plan+=("${CACHE_DIR}/")
for p in "${PROFILE_CANDIDATES[@]}"; do
    [ -f "${p}" ] && grep -q "Source bash aliases" "${p}" && plan+=("source block in ${p}")
done

if [ ${#plan[@]} -eq 0 ]; then
    echo "Nothing installed — nothing to do."
    exit 0
fi

echo "The following will be removed:"
printf '  - %s\n' "${plan[@]}"
echo ""
echo "Note: ${TARGET} will be backed up to ${BACKUP} first."

if [ "${dry_run}" = true ]; then
    echo ""
    echo "[dry-run] no changes made."
    exit 0
fi

if [ "${yes}" != true ]; then
    read -r -p "Proceed with uninstall? [y/N] " confirm || true
    if [[ ! "${confirm}" =~ ^[Yy]$ ]]; then
        echo "Uninstall cancelled."
        exit 0
    fi
fi

# Back up the main file before removing anything
if [ -f "${TARGET}" ]; then
    cp "${TARGET}" "${BACKUP}"
    say "backed up ${TARGET} -> ${BACKUP}"
fi
remove_file "${TARGET}"

# Remove manifest-tracked modules only; keep user files and the dir if any
# remain.
if [ -d "${TARGET_DIR}" ]; then
    if [ -f "${MANIFEST}" ]; then
        while IFS= read -r module; do
            remove_file "${TARGET_DIR}/${module}"
        done < "${MANIFEST}"
        remove_file "${MANIFEST}"
    else
        # No manifest (pre-manifest install): remove known module names only.
        for module in git-core.sh git-workflow.sh git-aliases.sh system.sh text.sh shellcheck.sh; do
            remove_file "${TARGET_DIR}/${module}"
        done
    fi
    if [ -z "$(ls -A "${TARGET_DIR}" 2>/dev/null)" ]; then
        remove_dir "${TARGET_DIR}"
    else
        echo "  kept ${TARGET_DIR}/ (contains files not installed by this tool):"
        find "${TARGET_DIR}" -mindepth 1 -maxdepth 1 -print | sed 's|.*/|    |'
    fi
fi

remove_dir "${CACHE_DIR}"

for p in "${PROFILE_CANDIDATES[@]}"; do
    strip_profile_block "${p}"
done

echo ""
echo "Uninstall complete. Your previous ${TARGET}.bak (if any) was left untouched;"
echo "restore it or ${BACKUP} manually if needed."
