#!/usr/bin/env bash
# shellcheck shell=bash

# Unified error handling helpers.

handle_error() {
    local exit_code=$1
    local function_name=${2:-unknown}
    local command=${3:-unknown}

    log_error "Error in ${function_name}: ${command} (exit code: ${exit_code})"

    exit "$exit_code"
}

setup_error_trap() {
    trap 'handle_error $? "${FUNCNAME[*]:-main}" "${BASH_COMMAND:-unknown}"' ERR
}

