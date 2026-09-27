#!/usr/bin/env bash
# shellcheck shell=bash

# Validation helpers for files and domain lists.

validate_file_exists() {
    local file=$1
    local description=${2:-File}

    if [[ ! -f "$file" ]]; then
        log_error "${description} not found: ${file}"
        return 1
    fi
}

validate_domain_list() {
    local file=$1
    local description=${2:-Domain list}

    if ! validate_file_exists "$file" "$description"; then
        return 1
    fi

    # One grep pass selects the invalid lines; the (usually empty) result is
    # only then walked line by line, as before.
    local domain_regex='^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$'
    local invalid_lines
    invalid_lines=$(grep -Ev "$domain_regex" "$file" | grep -v '^$') || true

    if [[ -n "$invalid_lines" ]]; then
        local count=0
        while IFS= read -r domain; do
            log_warn "Invalid domain format: ${domain}"
            ((count++)) || true
        done <<<"$invalid_lines"
        log_warn "Found ${count} invalid domains in ${description}"
    fi
}
