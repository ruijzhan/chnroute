#!/usr/bin/env bash
# shellcheck shell=bash

# Download helpers with retry logic.
#
# The loop below is the single retry point: curl is invoked without its own
# --retry because that flag only covers transient HTTP errors, while the loop
# retries every failure kind with exponential backoff.
download_with_retry() {
    local url=$1
    local output=$2
    local timeout=${3:-$DEFAULT_CONNECT_TIMEOUT}
    local retries=${4:-$DEFAULT_RETRY_COUNT}
    local retry_delay=${5:-$DEFAULT_RETRY_DELAY}

    log_info "Downloading ${url} -> ${output}"

    local curl_cmd=(
        curl -fsSL
        --connect-timeout "$timeout"
        --max-time "$((timeout * DEFAULT_RETRY_MAX_TIME_FACTOR))"
        --keepalive-time 30
        -H "User-Agent: Mozilla/5.0 (compatible; chnroute/${SCRIPT_VERSION})"
    )
    if (( $# > 5 )); then
        curl_cmd+=("${@:6}")
    fi
    curl_cmd+=("$url" -o "$output")

    local attempt=0 curl_exit=0
    until "${curl_cmd[@]}"; do
        curl_exit=$?
        # Assignment, not ((attempt++)): post-increment from 0 evaluates to 0,
        # whose non-zero status would abort the script under set -e before the
        # first retry ever runs.
        attempt=$((attempt + 1))
        if (( attempt < retries )); then
            log_warn "Download failed (exit ${curl_exit}), retry ${attempt}/${retries} in ${retry_delay}s"
            sleep "$retry_delay"
            retry_delay=$((retry_delay * 2))
        else
            log_error "Failed to download ${url} after ${retries} attempts"
            return "$curl_exit"
        fi
    done

    log_success "Downloaded ${url}"
}
