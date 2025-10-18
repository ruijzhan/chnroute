#!/usr/bin/env bash
# shellcheck shell=bash

# Dependency checking helpers.

check_dependencies_detailed() {
    local missing_tools=()
    local optional_missing=()

    local required_tools=(bash curl awk sort grep base64 mktemp split wc sed)
    local optional_tools=(wget bc nproc jq tee)

    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    for tool in "${optional_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            optional_missing+=("$tool")
        fi
    done

    if (( ${#missing_tools[@]} > 0 )); then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_error "Please install the missing dependencies before continuing."
        return 1
    fi

    if (( ${#optional_missing[@]} > 0 )); then
        log_warn "Optional tools not found: ${optional_missing[*]}"
    fi

    if (( BASH_VERSINFO[0] < 4 )); then
        log_error "Bash 4.0 or higher is required (current: ${BASH_VERSION})"
        return 1
    fi

    log_success "Dependency check passed"
    return 0
}

