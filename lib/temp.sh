#!/usr/bin/env bash
# shellcheck shell=bash

# Temporary directory utilities.

create_temp_root() {
    local prefix=${TEMP_FILE_PREFIX:-chnroute_}
    if [[ -d /dev/shm && -w /dev/shm ]]; then
        if ! TMP_DIR=$(mktemp -d -p /dev/shm "${prefix}XXXXXX" 2>/dev/null); then
            TMP_DIR=""
        fi
    fi

    if [[ -z "${TMP_DIR}" ]]; then
        TMP_DIR=$(mktemp -d -t "${prefix}XXXXXX")
    fi

    mkdir -p "${TMP_DIR}/processing" "${TMP_DIR}/cache" "${TMP_DIR}/checkpoints"
    log_debug "Temporary directory created at ${TMP_DIR}"
}

cleanup_temp_root() {
    if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
        log_debug "Temporary directory ${TMP_DIR} removed"
    fi
}

setup_cleanup_trap() {
    trap cleanup_temp_root EXIT
}
