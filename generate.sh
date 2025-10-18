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
PARALLEL_THREADS=""

cleanup_artifacts() {
    if [[ -f "${SCRIPT_DIR}/${OUTPUT_GFWLIST_AUTOPROXY}" ]]; then
        rm -f "${SCRIPT_DIR}/${OUTPUT_GFWLIST_AUTOPROXY}"
        log_debug "Removed artifact ${OUTPUT_GFWLIST_AUTOPROXY}"
    fi
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

run_gfwlist2dnsmasq() {
    log_info "Generating domain list via ${GFWLIST2DNSMASQ_SH}..."

    local script_path="${SCRIPT_DIR}/${GFWLIST2DNSMASQ_SH}"
    local autop_proxy="${SCRIPT_DIR}/${OUTPUT_GFWLIST_AUTOPROXY}"
    local output_path="${SCRIPT_DIR}/${GFWLIST_TXT}"
    local include_path="${SCRIPT_DIR}/${INCLUDE_LIST_TXT}"
    local exclude_path="${SCRIPT_DIR}/${EXCLUDE_LIST_TXT}"
    local log_file="${TMP_DIR}/gfwlist2dnsmasq.log"

    if [[ ! -f "$script_path" ]]; then
        log_error "${GFWLIST2DNSMASQ_SH} not found under ${SCRIPT_DIR}"
        return 1
    fi

    if [[ ! -f "$autop_proxy" ]]; then
        log_error "${OUTPUT_GFWLIST_AUTOPROXY} not found. Run parallel downloads first."
        return 1
    fi

    if bash "$script_path" \
        --domain-list \
        --extra-domain-file "$include_path" \
        --exclude-domain-file "$exclude_path" \
        --output "$output_path" >"$log_file" 2>&1; then
        local domain_count
        domain_count=$(wc -l <"$output_path")
        log_success "Generated ${GFWLIST_TXT} with ${domain_count} domains"
    else
        local exit_code=$?
        log_error "Failed to generate ${GFWLIST_TXT} (exit code ${exit_code}). See ${log_file} for details."
        return 1
    fi
}

create_gfwlist_rsc() {
    local version=$1
    local output_rsc=$2
    local input_file="${SCRIPT_DIR}/${GFWLIST_TXT}"

    if ! validate_file_exists "$input_file" "Generated domain list"; then
        return 1
    fi

    log_info "Creating RouterOS script ${output_rsc} for version ${version}..."

    local tmp_rsc="${TMP_DIR}/processing/${output_rsc}"
    local processed_domains="${TMP_DIR}/processing/${output_rsc}.domains"

    process_domains_parallel "$input_file" "$processed_domains" "$PARALLEL_THREADS"

    local domain_count
    domain_count=$(wc -l <"$input_file")

    cat <<EOL >"$tmp_rsc"
# RouterOS script for GFW domain list - Version ${version}
# Source: ${SCRIPT_REPO}

:global dnsserver
/ip dns static remove [/ip dns static find forward-to=${DNS_SERVER} ]
/ip dns static
:local domainList {
EOL

    cat "$processed_domains" >>"$tmp_rsc"

    cat <<EOL >>"$tmp_rsc"
}

:foreach domain in=\$domainList do={
    /ip dns static add forward-to=${DNS_SERVER} type=FWD address-list=${LIST_NAME} match-subdomain=yes name=\$domain
}

/ip dns cache flush
/log info "GFW domain list updated with ${domain_count} domains"
EOL

    mv "$tmp_rsc" "${SCRIPT_DIR}/${output_rsc}"
    log_success "Created ${output_rsc} with ${domain_count} domains"
}

generate_cn_ip_list() {
    local input_file=$1
    local output_file=$2
    local timeout=$3

    if [[ $# -ne 3 ]]; then
        log_error "Usage: generate_cn_ip_list <input> <output> <timeout>"
        return 1
    fi

    if ! validate_file_exists "$input_file" "RouterOS source script"; then
        return 1
    fi

    local tmp_rsc
    local processed_ips
    tmp_rsc="${TMP_DIR}/processing/$(basename "$output_file")"
    processed_ips="${TMP_DIR}/processing/$(basename "$output_file").ips"

    cat <<EOL >"$tmp_rsc"
/log info "Loading CN ipv4 address list"
/ip firewall address-list remove [/ip firewall address-list find list=CN]
/ip firewall address-list
:local ipList {
EOL

    local ip_count
    if ! ip_count=$(process_ip_stream "$input_file" "$processed_ips"); then
        log_error "Failed to parse IP addresses from ${input_file}"
        return 1
    fi

    if [[ -z "$ip_count" || "$ip_count" -eq 0 ]]; then
        log_error "No IP addresses found in ${input_file}"
        return 1
    fi

    cat "$processed_ips" >>"$tmp_rsc"

    cat <<EOL >>"$tmp_rsc"
}
:foreach ip in=\$ipList do={
    /ip firewall address-list add address=\$ip list=CN timeout=${timeout}
}
EOL

    mv "$tmp_rsc" "$output_file"
    log_success "Generated ${output_file} with ${ip_count} IP addresses"
}

modify_cn_rsc() {
    local input_file="${SCRIPT_DIR}/${CN_RSC}"
    local mem_output="${SCRIPT_DIR}/${CN_MEM_RSC}"

    if ! validate_file_exists "$input_file" "${CN_RSC}"; then
        return 1
    fi

    log_info "Creating CN list variants..."

    generate_cn_ip_list "$input_file" "$mem_output" "248d"

    local tmp_permanent="${TMP_DIR}/cache/${CN_RSC}"
    generate_cn_ip_list "$input_file" "$tmp_permanent" "0"
    mv "$tmp_permanent" "$input_file"
    log_success "Updated CN list variants"
}

check_git_status() {
    log_info "Checking git repository status..."

    if ! git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        log_warn "Not inside a git repository. Skipping git status checks."
        return 0
    fi

    if [[ ! -f "${SCRIPT_DIR}/${GFWLIST_CONF}" ]] || ! git -C "$SCRIPT_DIR" ls-files --error-unmatch "$GFWLIST_CONF" >/dev/null 2>&1; then
        log_warn "${GFWLIST_CONF} is not tracked by git. Skipping checkout logic."
        return 0
    fi

    local changes
    changes=$(git -C "$SCRIPT_DIR" status -s | wc -l)
    if [[ "$changes" -eq 1 ]]; then
        log_info "Single change detected. Restoring ${GFWLIST_CONF}."
        if git -C "$SCRIPT_DIR" checkout "$GFWLIST_CONF"; then
            log_success "${GFWLIST_CONF} restored"
        else
            log_error "Failed to restore ${GFWLIST_CONF}"
            return 1
        fi
    else
        log_info "Multiple changes present. Leaving git state untouched."
    fi
}

parallel_downloads() {
    log_info "Starting parallel downloads..."

    local status_pipe="${TMP_DIR}/status_pipe"
    mkfifo "$status_pipe"

    local download_success=true
    local cn_success=false
    local parallel_pids=()

    (
        if download_with_retry "$CN_URL" "${SCRIPT_DIR}/${CN_RSC}" 60; then
            echo "cn_success" >"$status_pipe"
        else
            echo "cn_failed" >"$status_pipe"
        fi
    ) &
    parallel_pids+=("$!")

    (
        local tmp_base64="${TMP_DIR}/cache/gfwlist.base64"
        if download_with_retry "$GFWLIST_URL" "$tmp_base64" 60; then
            if $BASE64_DECODE "$tmp_base64" >"${SCRIPT_DIR}/${OUTPUT_GFWLIST_AUTOPROXY}"; then
                log_success "Decoded GFW list to ${OUTPUT_GFWLIST_AUTOPROXY}"
                echo "gfwlist_success" >"$status_pipe"
            else
                log_error "Failed to decode GFW list"
                echo "gfwlist_failed" >"$status_pipe"
            fi
        else
            log_error "Failed to download GFW list"
            echo "gfwlist_failed" >"$status_pipe"
        fi
    ) &
    parallel_pids+=("$!")

    for ((i = 0; i < 2; i++)); do
        if read -r status <"$status_pipe"; then
            case "$status" in
                cn_success)
                    cn_success=true
                    log_success "CN list downloaded successfully"
                    ;;
                cn_failed)
                    download_success=false
                    log_error "CN list download failed"
                    ;;
                gfwlist_success)
                    log_success "GFW list download and decode completed"
                    ;;
                gfwlist_failed)
                    download_success=false
                    log_error "GFW list download or decode failed"
                    ;;
            esac
        fi
    done

    for pid in "${parallel_pids[@]}"; do
        if ! wait "$pid"; then
            download_success=false
        fi
    done

    rm -f "$status_pipe"

    if $download_success; then
        log_success "All downloads completed"
        if $cn_success; then
            modify_cn_rsc
        fi
    else
        log_error "Some downloads failed. Aborting."
        return 1
    fi
}

main() {
    initialize_logging
    create_temp_root
    trap 'cleanup_artifacts; cleanup_temp_root' EXIT
    setup_error_trap
    setup_platform_specific
    check_dependencies_detailed

    check_system_resources
    local optimal_threads="${SYSTEM_OPTIMAL_THREADS:-$DEFAULT_THREAD_COUNT}"
    if ! [[ "$optimal_threads" =~ ^[0-9]+$ ]]; then
        log_warn "Detected non-numeric optimal thread value '${optimal_threads}', defaulting to ${DEFAULT_THREAD_COUNT}"
        optimal_threads=$DEFAULT_THREAD_COUNT
    fi
    if [[ -z "${PARALLEL_THREADS:-}" ]]; then
        PARALLEL_THREADS=$optimal_threads
        log_info "Using ${PARALLEL_THREADS} parallel threads for domain processing"
    else
        log_info "Using user-defined parallel thread count: ${PARALLEL_THREADS}"
        if ! [[ "$PARALLEL_THREADS" =~ ^[0-9]+$ ]]; then
            log_warn "Provided parallel thread count '${PARALLEL_THREADS}' is not numeric, defaulting to ${optimal_threads}"
            PARALLEL_THREADS=$optimal_threads
        fi
    fi

    local start_time
    start_time=$(date +%s)
    local exit_code=0

    log_info "Starting chnroute generation pipeline..."

    log_info "Step 1/5: Downloading source data"
    if ! parallel_downloads; then
        exit_code=1
    fi

    log_info "Step 2/5: Sorting custom domain lists"
    sort_files

    log_info "Step 3/5: Generating domain list"
    if ! run_gfwlist2dnsmasq; then
        exit_code=1
    fi

    if [[ $exit_code -eq 0 ]]; then
        log_info "Step 4/5: Creating RouterOS scripts"
        if ! create_gfwlist_rsc "v7" "$GFWLIST_V7_RSC"; then
            exit_code=1
        fi
    fi

    log_info "Step 5/5: Checking git repository"
    check_git_status || exit_code=1

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
