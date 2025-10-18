#!/usr/bin/env bash
# shellcheck shell=bash

# Structured logging utilities with levels and optional log file support.

readonly LOG_LEVEL_DEBUG=0
readonly LOG_LEVEL_INFO=1
readonly LOG_LEVEL_WARN=2
readonly LOG_LEVEL_ERROR=3

LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

readonly COLOR_RESET=$'\033[0m'
readonly COLOR_RED=$'\033[0;31m'
readonly COLOR_GREEN=$'\033[0;32m'
readonly COLOR_YELLOW=$'\033[1;33m'
readonly COLOR_BLUE=$'\033[0;34m'

_log_dispatch() {
    local level_name=$1
    local level_value=$2
    local color=$3
    shift 3
    local message="$*"

    if (( LOG_LEVEL > level_value )); then
        return
    fi

    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    printf '[%s] %b[%s]%b %s\n' "$timestamp" "$color" "$level_name" "$COLOR_RESET" "$message"
}

log_debug() {
    _log_dispatch "DEBUG" "$LOG_LEVEL_DEBUG" "$COLOR_BLUE" "$@"
}

log_info() {
    _log_dispatch "INFO" "$LOG_LEVEL_INFO" "$COLOR_BLUE" "$@"
}

log_warn() {
    _log_dispatch "WARN" "$LOG_LEVEL_WARN" "$COLOR_YELLOW" "$@"
}

log_error() {
    _log_dispatch "ERROR" "$LOG_LEVEL_ERROR" "$COLOR_RED" "$@"
}

log_success() {
    _log_dispatch "SUCCESS" "$LOG_LEVEL_INFO" "$COLOR_GREEN" "$@"
}

initialize_logging() {
    # Logging disabled - output to stdout only
    :
}

