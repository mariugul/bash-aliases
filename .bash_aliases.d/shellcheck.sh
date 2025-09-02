#!/bin/bash
# Shellcheck Integration
# Functions and aliases for bash script linting and validation

# Check if shellcheck is installed
check-shellcheck() {
    if ! command -v shellcheck &> /dev/null; then
        echo "shellcheck is not installed. Install it with:"
        echo "  Ubuntu/Debian: sudo apt-get install shellcheck"
        echo "  macOS: brew install shellcheck"
        echo "  Or visit: https://github.com/koalaman/shellcheck#installing"
        return 1
    fi
    return 0
}

# Run shellcheck on a single file
shellcheck-file() {
    local file="$1"
    if [[ -z "${file}" ]]; then
        echo "Usage: shellcheck-file <file>"
        return 1
    fi
    
    if [[ ! -f "${file}" ]]; then
        echo "Error: File '${file}' not found"
        return 1
    fi
    
    check-shellcheck || return 1
    
    echo "Checking ${file}..."
    shellcheck "${file}"
}

# Run shellcheck on all bash scripts in current directory
shellcheck-all() {
    check-shellcheck || return 1
    
    local files_found=0
    local files_with_issues=0
    
    echo "Running shellcheck on all bash scripts..."
    echo "=================================="
    
    # Check .bash_aliases if it exists
    if [[ -f ".bash_aliases" ]]; then
        echo "Checking .bash_aliases..."
        if ! shellcheck ".bash_aliases"; then
            ((files_with_issues++))
        fi
        ((files_found++))
        echo ""
    fi
    
    # Check install.sh if it exists
    if [[ -f "install.sh" ]]; then
        echo "Checking install.sh..."
        if ! shellcheck "install.sh"; then
            ((files_with_issues++))
        fi
        ((files_found++))
        echo ""
    fi
    
    # Check all .sh files in .bash_aliases.d/
    if [[ -d ".bash_aliases.d" ]]; then
        for script in .bash_aliases.d/*.sh; do
            if [[ -f "${script}" ]]; then
                echo "Checking ${script}..."
                if ! shellcheck "${script}"; then
                    ((files_with_issues++))
                fi
                ((files_found++))
                echo ""
            fi
        done
    fi
    
    # Summary
    echo "=================================="
    echo "Shellcheck Summary:"
    echo "  Files checked: ${files_found}"
    echo "  Files with issues: ${files_with_issues}"
    echo "  Files clean: $((files_found - files_with_issues))"
    
    if [[ ${files_with_issues} -eq 0 ]]; then
        echo "🎉 All scripts passed shellcheck!"
        return 0
    else
        echo "⚠️  Some scripts have issues that should be addressed."
        return 1
    fi
}

# Run shellcheck with specific severity level
shellcheck-strict() {
    check-shellcheck || return 1
    
    local target="${1:-.}"
    echo "Running strict shellcheck (all severity levels)..."
    
    if [[ -f "${target}" ]]; then
        shellcheck --severity=style "${target}"
    else
        find "${target}" -name "*.sh" -o -name ".bash_aliases" -o -name "install.sh" | while read -r file; do
            echo "Checking ${file} (strict)..."
            shellcheck --severity=style "${file}"
            echo ""
        done
    fi
}

# Fix common shellcheck issues automatically (where safe)
shellcheck-fix() {
    echo "This function would implement automatic fixes for common shellcheck issues."
    echo "Currently not implemented - manual review recommended for safety."
    echo ""
    echo "Common fixes you can apply manually:"
    echo "  - Add quotes around variables: \$var -> \"\$var\""
    echo "  - Use [[ ]] instead of [ ] for conditionals"
    echo "  - Add 'set -euo pipefail' at the top of scripts"
    echo "  - Use \${var} instead of \$var for clarity"
}

# Install shellcheck if not present
install-shellcheck() {
    if command -v shellcheck &> /dev/null; then
        echo "shellcheck is already installed ($(shellcheck --version | head -n1))"
        return 0
    fi
    
    echo "Installing shellcheck..."
    
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y shellcheck
    elif command -v brew &> /dev/null; then
        brew install shellcheck
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y ShellCheck
    elif command -v yum &> /dev/null; then
        sudo yum install -y ShellCheck
    else
        echo "Could not detect package manager. Please install shellcheck manually:"
        echo "https://github.com/koalaman/shellcheck#installing"
        return 1
    fi
    
    echo "shellcheck installation complete!"
}

# Aliases for convenience
alias sc='shellcheck-file'
alias sca='shellcheck-all'
alias scs='shellcheck-strict'
alias scf='shellcheck-fix'
alias sci='install-shellcheck'
