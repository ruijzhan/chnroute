#!/usr/bin/env bash
# shellcheck shell=bash

# Dependency checking helpers.

check_dependencies_detailed() {
    local required_tools=(bash curl awk sort grep base64 mktemp wc)
    local missing_tools=()

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if (( ${#missing_tools[@]} > 0 )); then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install the missing dependencies before continuing."
        return 1
    fi

    if (( BASH_VERSINFO[0] < 4 )); then
        log_error "Bash 4.0 or higher is required (current: ${BASH_VERSION})"
        return 1
    fi

    log_success "Dependency check passed"
}
