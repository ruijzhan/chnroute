#!/usr/bin/env bash
# shellcheck shell=bash

# Validation helpers for files, domains, and IP addresses.

validate_file_exists() {
    local file=$1
    local description=${2:-File}

    if [[ ! -f "$file" ]]; then
        log_error "${description} not found: ${file}"
        return 1
    fi
    return 0
}

validate_directory_exists() {
    local dir=$1
    local description=${2:-Directory}

    if [[ ! -d "$dir" ]]; then
        log_error "${description} not found: ${dir}"
        return 1
    fi
    return 0
}

validate_domain_list() {
    local file=$1
    local description=${2:-Domain list}

    if ! validate_file_exists "$file" "$description"; then
        return 1
    fi

    local domain_regex='^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
    local invalid_domains=0

    while IFS= read -r domain; do
        if [[ -n "$domain" && ! "$domain" =~ $domain_regex ]]; then
            log_warn "Invalid domain format: ${domain}"
            ((invalid_domains++))
        fi
    done <"$file"

    if (( invalid_domains > 0 )); then
        log_warn "Found ${invalid_domains} invalid domains in ${description}"
    fi

    return 0
}

validate_ip_list() {
    local file=$1
    local description=${2:-IP list}

    if ! validate_file_exists "$file" "$description"; then
        return 1
    fi

    local ip_regex='^([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]{1,2})?$'
    local invalid_ips=0

    while IFS= read -r line; do
        if [[ $line =~ address=([0-9./]+) ]]; then
            local ip=${BASH_REMATCH[1]}
            if [[ ! $ip =~ $ip_regex ]]; then
                log_warn "Invalid IP format: ${ip}"
                ((invalid_ips++))
            fi
        fi
    done <"$file"

    if (( invalid_ips > 0 )); then
        log_warn "Found ${invalid_ips} invalid IP entries in ${description}"
    fi

    return 0
}
