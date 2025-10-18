#!/usr/bin/env bash
# shellcheck shell=bash

# System resource helpers.

SYSTEM_OPTIMAL_THREADS=${DEFAULT_THREAD_COUNT:-1}

check_system_resources() {
    log_info "Checking system resources..."

    local available_memory=1024
    if command -v free >/dev/null 2>&1; then
        available_memory=$(free -m | awk 'NR==2{printf "%d", $7}')
    fi

    local available_disk
    available_disk=$(df . | awk 'NR==2{printf "%d", $4}')

    local cpu_cores
    cpu_cores=$(nproc 2>/dev/null || echo "1")

    if (( available_memory < 512 )); then
        log_warn "Low available memory: ${available_memory}MB"
    fi

    if (( available_disk < 102400 )); then
        log_warn "Low disk space: ${available_disk}KB"
    fi

    local optimal_threads=$(( cpu_cores * 2 ))
    if (( optimal_threads > MAX_THREAD_COUNT )); then
        optimal_threads=$MAX_THREAD_COUNT
    fi
    if (( optimal_threads < 1 )); then
        optimal_threads=1
    fi

    log_info "Resources OK - Memory: ${available_memory}MB, Disk: ${available_disk}KB, CPU cores: ${cpu_cores}"
    SYSTEM_OPTIMAL_THREADS=$optimal_threads
}
