#!/bin/bash
# Maintenance Utilities
# Disk, docker, package, and log cleanup for servers and dev machines.
# Destructive commands are dry runs by default — pass --yes to execute.

_maint-usage() {
    echo "Usage: ${1} [--dry-run|-n] [--yes|-y]${2:+ ${2}}"
}

# Show the largest files/directories under a path, biggest first.
# Usage: disk-top [path] [count]   (defaults: . and 20)
disk-top() {
    local target="${1:-.}" count="${2:-20}"
    du -ah "${target}" 2>/dev/null | sort -rh | head -n "${count}"
}

# Reclaim docker space (stopped containers, dangling images, unused
# networks and build cache). Dry run shows usage and candidates only.
docker-clean() {
    local dry_run=true
    while [ $# -gt 0 ]; do
        case "${1}" in
            --dry-run|-n) ;;
            --yes|-y)     dry_run=false ;;
            --help|-h)    _maint-usage docker-clean; return 0 ;;
            *)            _maint-usage docker-clean >&2; return 1 ;;
        esac
        shift
    done

    if ! command -v docker > /dev/null 2>&1; then
        echo "docker-clean: 'docker' is not installed." >&2
        return 1
    fi

    echo "Docker disk usage:"
    docker system df

    if [ "${dry_run}" = true ]; then
        local stopped dangling
        stopped=$(docker ps -aq --filter status=exited | wc -l)
        dangling=$(docker images -qf dangling=true | wc -l)
        echo ""
        echo "Dry run — nothing removed."
        echo "  stopped containers: ${stopped}"
        echo "  dangling images:    ${dangling}"
        echo "Run 'docker-clean --yes' to remove them ('docker system prune -f')."
        return 0
    fi

    docker system prune -f
}

# Autoremove unused packages and clear the apt package cache
# (Debian/Ubuntu only). Dry run simulates the autoremove and reports the
# cache size; no sudo is used until --yes is passed.
apt-clean() {
    local dry_run=true
    while [ $# -gt 0 ]; do
        case "${1}" in
            --dry-run|-n) ;;
            --yes|-y)     dry_run=false ;;
            --help|-h)    _maint-usage apt-clean; return 0 ;;
            *)            _maint-usage apt-clean >&2; return 1 ;;
        esac
        shift
    done

    if ! command -v apt-get > /dev/null 2>&1; then
        echo "apt-clean: 'apt-get' is not installed (Debian/Ubuntu only)." >&2
        return 1
    fi

    if [ "${dry_run}" = true ]; then
        echo "Dry run — nothing removed. 'apt-get autoremove' would do:"
        apt-get -s autoremove
        if [ -d /var/cache/apt/archives ]; then
            echo "Package cache size: $(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1)"
        fi
        echo "Run 'apt-clean --yes' to autoremove and clear the package cache."
        return 0
    fi

    sudo apt-get autoremove -y && sudo apt-get clean
}

# Vacuum systemd journal logs down to a size limit (default 500M).
# Usage: journal-clean [--yes|-y] [size]
journal-clean() {
    local dry_run=true size="500M"
    while [ $# -gt 0 ]; do
        case "${1}" in
            --dry-run|-n) ;;
            --yes|-y)     dry_run=false ;;
            --help|-h)    _maint-usage journal-clean "[size]"; return 0 ;;
            -*)           _maint-usage journal-clean "[size]" >&2; return 1 ;;
            *)            size="${1}" ;;
        esac
        shift
    done

    if ! command -v journalctl > /dev/null 2>&1; then
        echo "journal-clean: 'journalctl' is not installed (systemd only)." >&2
        return 1
    fi

    if [ "${dry_run}" = true ]; then
        journalctl --disk-usage
        echo "Dry run — nothing removed."
        echo "Run 'journal-clean --yes [size]' to vacuum (default size: ${size})."
        return 0
    fi

    sudo journalctl --vacuum-size="${size}"
}

# Show listening TCP/UDP ports.
ports() {
    if command -v ss > /dev/null 2>&1; then
        ss -tuln
    elif command -v netstat > /dev/null 2>&1; then
        netstat -tuln
    else
        echo "ports: neither 'ss' nor 'netstat' is available." >&2
        return 1
    fi
}
