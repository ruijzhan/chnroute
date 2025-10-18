#!/usr/bin/env bash
# shellcheck shell=bash

# Download helpers with retry logic.

download_with_retry() {
    local url=$1
    local output=$2
    local timeout=${3:-$DEFAULT_CONNECT_TIMEOUT}
    local retries=${4:-$DEFAULT_RETRY_COUNT}
    local retry_delay=${5:-$DEFAULT_RETRY_DELAY}
    local extra_args=()
    if (( $# > 5 )); then
        extra_args=("${@:6}")
    fi

    log_info "Downloading ${url} -> ${output}"

    local attempt=0
    local curl_exit=0

    while (( attempt < retries )); do
        if curl -fsSL \
            --connect-timeout "$timeout" \
            --max-time "$((timeout * DEFAULT_RETRY_MAX_TIME_FACTOR))" \
            --retry "$retries" \
            --retry-delay "$retry_delay" \
            --retry-max-time "$((timeout * DEFAULT_RETRY_MAX_TIME_FACTOR))" \
            --dns-servers "8.8.8.8,1.1.1.1" \
            --keepalive-time 30 \
            --no-buffer \
            -H "User-Agent: Mozilla/5.0 (compatible; chnroute/${SCRIPT_VERSION})" \
            "${extra_args[@]}" \
            "$url" -o "$output"; then
            log_success "Downloaded ${url}"
            return 0
        fi

        curl_exit=$?
        ((attempt++))

        if (( attempt < retries )); then
            log_warn "Download failed (exit ${curl_exit}), retry ${attempt}/${retries} in ${retry_delay}s"
            sleep "$retry_delay"
            retry_delay=$((retry_delay * 2))
        else
            log_error "Failed to download ${url} after ${retries} attempts"
        fi
    done

    return "$curl_exit"
}
