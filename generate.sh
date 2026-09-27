#!/usr/bin/env bash

# Script to generate RouterOS configuration files for China IP routes and GFW domain lists
# Author: ruijzhan
# Repository: https://github.com/ruijzhan/chnroute

set -euo pipefail

export LC_ALL=POSIX

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

# shellcheck source=lib/config.sh
. "${LIB_DIR}/config.sh"
# shellcheck source=lib/logger.sh
. "${LIB_DIR}/logger.sh"
# shellcheck source=lib/temp.sh
. "${LIB_DIR}/temp.sh"
# shellcheck source=lib/error.sh
. "${LIB_DIR}/error.sh"
# shellcheck source=lib/platform.sh
. "${LIB_DIR}/platform.sh"
# shellcheck source=lib/dependencies.sh
. "${LIB_DIR}/dependencies.sh"
# shellcheck source=lib/resources.sh
. "${LIB_DIR}/resources.sh"
# shellcheck source=lib/validation.sh
. "${LIB_DIR}/validation.sh"
# shellcheck source=lib/downloader.sh
. "${LIB_DIR}/downloader.sh"
# shellcheck source=lib/processor.sh
. "${LIB_DIR}/processor.sh"

TMP_DIR=""

cleanup_artifacts() {
    rm -f "${SCRIPT_DIR}/${CN_RSC}.tmp" \
        "${SCRIPT_DIR}/${CN_MEM_RSC}.tmp" \
        "${SCRIPT_DIR}/${GFWLIST_V7_RSC}.tmp"
    log_debug "Removed temporary artifacts"
}

sort_files() {
    log_info "Sorting and validating custom domain lists..."

    local include_path="${SCRIPT_DIR}/${INCLUDE_LIST_TXT}"
    local exclude_path="${SCRIPT_DIR}/${EXCLUDE_LIST_TXT}"

    for file in "$include_path" "$exclude_path"; do
        if [[ ! -f "$file" ]]; then
            log_warn "$(basename "$file") not found, creating empty file"
            : >"$file"
        fi

        sort -uo "$file" "$file"
    done

    validate_domain_list "$include_path" "Include domain list"
    validate_domain_list "$exclude_path" "Exclude domain list"

    local include_count exclude_count
    include_count=$(wc -l <"$include_path")
    exclude_count=$(wc -l <"$exclude_path")
    log_info "Include domains: ${include_count}, Exclude domains: ${exclude_count}"
}

# Builds gfwlist.txt from the downloaded GFWList copy plus the custom
# include/exclude lists. Same pipeline the standalone gfwlist2dnsmasq.sh runs,
# shared via lib/processor.sh, but without a second script process.
generate_domain_list() {
    local gfwlist_file="${TMP_DIR}/cache/gfwlist.txt"
    local domain_file="${TMP_DIR}/processing/domains.txt"

    if [[ ! -s "$gfwlist_file" ]]; then
        log_error "GFWList input is empty or missing: ${gfwlist_file}"
        return 1
    fi

    log_info "Extracting domains from GFWList"
    if ! extract_domains "$gfwlist_file" "$domain_file"; then
        log_error "Failed to extract domains from GFWList"
        return 1
    fi

    merge_domain_lists "$domain_file" \
        "${SCRIPT_DIR}/${INCLUDE_LIST_TXT}" "${SCRIPT_DIR}/${EXCLUDE_LIST_TXT}"

    local domain_count
    domain_count=$(wc -l <"$domain_file")
    mv "$domain_file" "${SCRIPT_DIR}/${GFWLIST_TXT}"
    log_success "Generated ${GFWLIST_TXT} with ${domain_count} domains"
}

create_gfwlist_rsc() {
    local version=$1
    local output_rsc=$2
    local input_file="${SCRIPT_DIR}/${GFWLIST_TXT}"

    if ! validate_file_exists "$input_file" "Generated domain list"; then
        return 1
    fi

    log_info "Creating RouterOS script ${output_rsc} for version ${version}..."

    if [[ ! -s "$input_file" ]]; then
        log_warn "Domain list is empty: ${input_file}"
    fi

    local domain_count
    domain_count=$(wc -l <"$input_file")

    # Written next to the target so the final mv is a rename, not a copy.
    # Domains are streamed straight into the script, no intermediate file.
    local tmp_rsc="${SCRIPT_DIR}/${output_rsc}.tmp"
    {
        cat <<EOL
# RouterOS script for GFW domain list - Version ${version}
# Source: ${SCRIPT_REPO}

:global dnsserver
/ip dns static remove [/ip dns static find forward-to=${DNS_SERVER} ]
/ip dns static
:local domainList {
EOL
        awk '{printf "    \"%s\";\n", $0}' "$input_file"
        cat <<EOL
}

:foreach domain in=\$domainList do={
    /ip dns static add forward-to=${DNS_SERVER} type=FWD address-list=${LIST_NAME} match-subdomain=yes name=\$domain
}

/ip dns cache flush
/log info "GFW domain list updated with ${domain_count} domains"
EOL
    } >"$tmp_rsc"
    mv "$tmp_rsc" "${SCRIPT_DIR}/${output_rsc}"
    log_success "Created ${output_rsc} with ${domain_count} domains"
}

# Renders a RouterOS address-list script from pre-extracted IP entries.
render_cn_rsc() {
    local ip_entries=$1
    local ip_count=$2
    local output_file=$3
    local timeout=$4

    local tmp_rsc="${output_file}.tmp"
    {
        cat <<EOL
/log info "Loading CN ipv4 address list"
/ip firewall address-list remove [/ip firewall address-list find list=CN]
/ip firewall address-list
:local ipList {
EOL
        cat "$ip_entries"
        cat <<EOL
}
:foreach ip in=\$ipList do={
    /ip firewall address-list add address=\$ip list=CN timeout=${timeout}
}
EOL
    } >"$tmp_rsc"
    mv "$tmp_rsc" "$output_file"
    log_success "Generated ${output_file} with ${ip_count} IP addresses"
}

generate_cn_ip_list() {
    local input_file=$1
    local mem_output=$2

    if ! validate_file_exists "$input_file" "${CN_RSC}"; then
        return 1
    fi

    log_info "Creating CN list variants..."

    # The source holds ~8000 addresses and both variants use the same list, so
    # it is extracted once instead of once per variant.
    local ip_entries="${TMP_DIR}/processing/cn.ips"
    local ip_count
    if ! ip_count=$(process_ip_stream "$input_file" "$ip_entries"); then
        log_error "Failed to parse IP addresses from ${input_file}"
        return 1
    fi

    if [[ -z "$ip_count" || "$ip_count" -eq 0 ]]; then
        log_error "No IP addresses found in ${input_file}"
        return 1
    fi

    render_cn_rsc "$ip_entries" "$ip_count" "$mem_output" "248d"
    render_cn_rsc "$ip_entries" "$ip_count" "$input_file" "0"
    log_success "Updated CN list variants"
}

parallel_downloads() {
    log_info "Starting parallel downloads..."

    # Both sources are independent, so they are fetched concurrently and the
    # exit status of each job decides the outcome.
    download_with_retry "$CN_URL" "${SCRIPT_DIR}/${CN_RSC}" 60 &
    local cn_pid=$!

    # The decoded copy is only written inside the temp tree on success, so a
    # failed download can never be mistaken for a usable (empty) GFWList.
    (
        local encoded_file="${TMP_DIR}/cache/gfwlist.base64"
        download_with_retry "$GFWLIST_URL" "$encoded_file" 60 &&
            $BASE64_DECODE "$encoded_file" >"${TMP_DIR}/cache/gfwlist.txt"
    ) &
    local gfwlist_pid=$!

    local cn_ok=false
    local gfwlist_ok=false
    if wait "$cn_pid"; then
        cn_ok=true
    else
        log_error "CN list download failed"
    fi
    if wait "$gfwlist_pid"; then
        gfwlist_ok=true
    else
        log_error "GFW list download or decode failed"
    fi

    if ! $cn_ok || ! $gfwlist_ok; then
        log_error "Some downloads failed. Aborting."
        return 1
    fi

    log_success "All downloads completed"
}

main() {
    create_temp_root
    trap 'cleanup_artifacts; cleanup_temp_root' EXIT
    setup_error_trap
    setup_platform_specific
    check_dependencies_detailed

    check_system_resources
    local start_time
    start_time=$(date +%s)
    local exit_code=0

    log_info "Starting chnroute generation pipeline..."

    log_info "Step 1/4: Downloading source data and creating CN lists"
    if ! parallel_downloads; then
        exit_code=1
    elif ! generate_cn_ip_list "${SCRIPT_DIR}/${CN_RSC}" "${SCRIPT_DIR}/${CN_MEM_RSC}"; then
        exit_code=1
    fi

    log_info "Step 2/4: Sorting custom domain lists"
    sort_files

    log_info "Step 3/4: Generating domain list"
    if ! generate_domain_list; then
        exit_code=1
    fi

    if [[ $exit_code -eq 0 ]]; then
        log_info "Step 4/4: Creating RouterOS scripts"
        if ! create_gfwlist_rsc "v7" "$GFWLIST_V7_RSC"; then
            exit_code=1
        fi
    fi

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    if [[ $exit_code -eq 0 ]]; then
        log_success "All tasks completed successfully in ${duration} seconds"
    else
        log_error "Completed with errors in ${duration} seconds. Check logs for details."
    fi

    return "$exit_code"
}

main
