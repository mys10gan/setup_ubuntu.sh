#!/usr/bin/env bash

set -euo pipefail

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default log file: root -> /var/log, user -> home
if [[ -z "${LOG_FILE:-}" ]]; then
    if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
        LOG_FILE="/var/log/myst-setup.log"
    else
        LOG_FILE="$HOME/.myst_setup.log"
    fi
fi

# Try to create log file; if it fails, we just skip file logging
if [[ -n "${LOG_FILE:-}" ]]; then
    touch "$LOG_FILE" 2>/dev/null || LOG_FILE=""
fi

log() {
    local level=${1:-INFO}
    shift || true
    local message="$*"

    local ts
    ts="$(date +'%Y-%m-%d %H:%M:%S')"
    local upper_level="${level^^}"

    local color prefix
    case "$upper_level" in
        INFO)    color="$GREEN" ;;
        WARN)    color="$YELLOW" ;;
        ERROR)   color="$RED" ;;
        SUCCESS) color="$CYAN" ;;
        DEBUG|*) color="$BLUE" ;;
    esac

    prefix="[$upper_level] [$ts]"

    # Console (colored)
    echo -e "${color}${prefix}${NC} $message"

    # Log file (plain)
    if [[ -n "${LOG_FILE:-}" ]]; then
        echo "${prefix} $message" >>"$LOG_FILE"
    fi
}

require_root() {
    if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
        log ERROR "This script must be run as root (or via sudo)."
        exit 1
    fi
}

confirm() {
    local prompt="$1"
    local default="${2:-y}"
    local reply

    if [[ "$default" == "y" ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi

    read -r -p "$prompt" reply || reply=""
    reply=${reply:-$default}

    case "$reply" in
        [Yy]*) return 0 ;;
        *)     return 1 ;;
    esac
}

