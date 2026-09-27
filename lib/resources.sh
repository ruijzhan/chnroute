#!/usr/bin/env bash
# shellcheck shell=bash

# System resource helpers.

check_system_resources() {
    log_info "Checking system resources..."

    local available_memory=1024
    if command -v free >/dev/null 2>&1; then
        available_memory=$(free -m | awk 'NR==2{printf "%d", $7}')
    fi

    local available_disk
    available_disk=$(df -k . | awk 'NR==2{printf "%d", $4}')

    if (( available_memory < 512 )); then
        log_warn "Low available memory: ${available_memory}MB"
    fi

    if (( available_disk < 102400 )); then
        log_warn "Low disk space: ${available_disk}KB"
    fi

    log_info "Resources OK - Memory: ${available_memory}MB, Disk: ${available_disk}KB"
}
