#!/usr/bin/env bash

# Name:        gfwlist2dnsmasq.sh
# Description: Convert GFWList into dnsmasq rules or domain lists
# Version:     1.1.0 (2025-05-24)
# Original Author: Cokebar Chi
# Original Website: https://github.com/cokebar
# Modified by: ruijzhan

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
# shellcheck source=lib/validation.sh
. "${LIB_DIR}/validation.sh"
# shellcheck source=lib/downloader.sh
# shellcheck source=lib/processor.sh
. "${LIB_DIR}/processor.sh"
. "${LIB_DIR}/downloader.sh"

TMP_DIR=""
OUT_TYPE='DNSMASQ_RULES'
DNS_IP='127.0.0.1'
INPUT_FILE=''
DNS_PORT='5353'
IPSET_NAME=''
OUT_FILE=''
WITH_IPSET=0
EXTRA_DOMAIN_FILE=''
EXCLUDE_DOMAIN_FILE=''
declare -a CURL_EXTRA_ARGS=()

usage() {
    cat <<-EOF

${COLOR_GREEN}GFWList to DNSMasq Converter${COLOR_RESET}

Description:  Convert GFWList into dnsmasq rules or domain lists
Version:      1.1.0 (2025-05-24)
Original:     https://github.com/cokebar/gfwlist2dnsmasq
Modified by:  ruijzhan

${COLOR_GREEN}Usage:${COLOR_RESET} bash gfwlist2dnsmasq.sh [options] -o FILE

${COLOR_GREEN}Options:${COLOR_RESET}
    -d, --dns <dns_ip>
                DNS IP address for the GFWList domains (default: 127.0.0.1)
    -p, --port <dns_port>
                DNS port for the GFWList domains (default: 5353)
    -s, --ipset <ipset_name>
                Ipset name for the GFWList domains
    -o, --output <FILE>
                Path to the output file (required)
    -i, --insecure
                Disable TLS certificate validation (curl only)
    -l, --domain-list
                Generate a simple domain list instead of dnsmasq rules
    --input <FILE>
                Use an already downloaded (decoded) GFWList file
    --exclude-domain-file <FILE>
                File with domains to exclude (one per line)
    --extra-domain-file <FILE>
                File with additional domains to include (one per line)
    -h, --help
                Display this help message
EOF
    exit "$1"
}

validate_output_path() {
    if [[ -z "$OUT_FILE" ]]; then
        log_error "No output file specified. Use -o/--output."
        usage 1
    fi

    if [[ -d "$OUT_FILE" ]]; then
        log_error "Output path '$OUT_FILE' is a directory."
        exit 1
    fi

    local parent_dir
    parent_dir=$(dirname "$OUT_FILE")
    if [[ "$parent_dir" != "." ]] && [[ ! -d "$parent_dir" ]]; then
        log_error "Output directory does not exist: ${parent_dir}"
        exit 1
    fi
}

get_args() {
    local IPV4_PATTERN='^((2[0-4][0-9]|25[0-5]|[01]?[0-9][0-9]?)\.){3}(2[0-4][0-9]|25[0-5]|[01]?[0-9][0-9]?)$'
    local IPV6_PATTERN='^(([0-9A-Fa-f]{1,4}:){7}[0-9A-Fa-f]{1,4}|(::1)|([0-9A-Fa-f]{1,4}:){1,7}:|:([0-9A-Fa-f]{1,4}:){1,7})(%.+)?$'

    while [[ $# -gt 0 ]]; do
        # Options taking a value only pick their target here; the value itself
        # is consumed once, after the case, so every option validates alike.
        local target=''
        local label=''
        case "$1" in
            --help|-h)
                usage 0
                ;;
            --domain-list|-l)
                OUT_TYPE='DOMAIN_LIST'
                log_info "Output type set to domain list"
                ;;
            --insecure|-i)
                CURL_EXTRA_ARGS+=("--insecure")
                log_warn "TLS certificate validation disabled"
                ;;
            --dns|-d)
                target=DNS_IP
                label='DNS IP'
                ;;
            --port|-p)
                target=DNS_PORT
                label='DNS port'
                ;;
            --ipset|-s)
                target=IPSET_NAME
                label='ipset name'
                ;;
            --output|-o)
                target=OUT_FILE
                label='output file'
                ;;
            --input)
                target=INPUT_FILE
                label='input file'
                ;;
            --extra-domain-file)
                target=EXTRA_DOMAIN_FILE
                label='extra domain file'
                ;;
            --exclude-domain-file)
                target=EXCLUDE_DOMAIN_FILE
                label='exclude domain file'
                ;;
            *)
                log_error "Unknown argument: $1"
                usage 1
                ;;
        esac

        if [[ -n "$target" ]]; then
            if [[ $# -lt 2 ]] || [[ ${2-} == -* ]]; then
                log_error "Missing value for ${label} parameter"
                usage 1
            fi
            printf -v "$target" '%s' "$2"
            log_info "${label^} set to ${!target}"
            shift
        fi
        shift
    done

    validate_output_path

    if [[ "$OUT_TYPE" == "DNSMASQ_RULES" ]]; then
        if [[ ! $DNS_IP =~ $IPV4_PATTERN ]] && [[ ! $DNS_IP =~ $IPV6_PATTERN ]]; then
            log_error "Invalid DNS server IP address: ${DNS_IP}"
            exit 1
        fi

        if ! [[ $DNS_PORT =~ ^[0-9]+$ ]] || (( DNS_PORT < 1 || DNS_PORT > 65535 )); then
            log_error "Invalid DNS port: ${DNS_PORT}. Must be between 1 and 65535."
            exit 1
        fi

        if [[ -n "$IPSET_NAME" ]]; then
            if [[ $IPSET_NAME =~ ^[[:alnum:]_]+(,[[:alnum:]_]+)*$ ]]; then
                WITH_IPSET=1
            else
                log_error "Invalid ipset name: ${IPSET_NAME}"
                exit 1
            fi
        fi
    fi

    if [[ -n "$EXTRA_DOMAIN_FILE" ]]; then
        if [[ -f "$EXTRA_DOMAIN_FILE" ]]; then
            validate_domain_list "$EXTRA_DOMAIN_FILE" "Extra domain list"
        else
            log_warn "Extra domain file not found: ${EXTRA_DOMAIN_FILE}. It will be ignored."
            EXTRA_DOMAIN_FILE=''
        fi
    fi

    if [[ -n "$EXCLUDE_DOMAIN_FILE" ]]; then
        if [[ -f "$EXCLUDE_DOMAIN_FILE" ]]; then
            validate_domain_list "$EXCLUDE_DOMAIN_FILE" "Exclude domain list"
        else
            log_warn "Exclude domain file not found: ${EXCLUDE_DOMAIN_FILE}. It will be ignored."
            EXCLUDE_DOMAIN_FILE=''
        fi
    fi

    if [[ -n "$INPUT_FILE" ]]; then
        if ! validate_file_exists "$INPUT_FILE" "GFWList input"; then
            exit 1
        fi
        if [[ ! -s "$INPUT_FILE" ]]; then
            log_error "GFWList input is empty: ${INPUT_FILE}"
            exit 1
        fi
    fi
}

process_gfwlist() {
    local gfwlist_file=$INPUT_FILE
    local domain_file="${TMP_DIR}/processing/domains.txt"

    if [[ -z "$gfwlist_file" ]]; then
        local base_url='https://github.com/gfwlist/gfwlist/raw/master/gfwlist.txt'
        local encoded_file="${TMP_DIR}/cache/gfwlist.base64"
        gfwlist_file="${TMP_DIR}/cache/gfwlist.txt"

        log_info "Fetching GFWList from ${base_url}"
        if ! download_with_retry "$base_url" "$encoded_file" 30 "$DEFAULT_RETRY_COUNT" "$DEFAULT_RETRY_DELAY" "${CURL_EXTRA_ARGS[@]}"; then
            log_error "Failed to download GFWList"
            exit 2
        fi

        log_info "Decoding base64 content"
        if ! $BASE64_DECODE "$encoded_file" >"$gfwlist_file"; then
            log_error "Failed to decode GFWList"
            exit 2
        fi
    else
        log_info "Using local GFWList copy: ${gfwlist_file}"
    fi

    log_info "Extracting domains from GFWList"
    if ! extract_domains "$gfwlist_file" "$domain_file"; then
        log_error "Failed to extract domains from GFWList"
        exit 2
    fi

    if [[ -n "$EXCLUDE_DOMAIN_FILE" ]]; then
        log_info "Applying exclude list ${EXCLUDE_DOMAIN_FILE}"
        local filtered_file="${domain_file}.filtered"
        if ! grep -vF -f "$EXCLUDE_DOMAIN_FILE" "$domain_file" >"$filtered_file"; then
            log_warn "All domains excluded by ${EXCLUDE_DOMAIN_FILE}"
        fi
        mv "$filtered_file" "$domain_file"
    fi

    if [[ -n "$EXTRA_DOMAIN_FILE" ]]; then
        log_info "Appending extra domains from ${EXTRA_DOMAIN_FILE}"
        grep -v '^[[:space:]]*$' "$EXTRA_DOMAIN_FILE" >>"$domain_file" || true
    fi

    LC_ALL=POSIX sort -u "$domain_file" -o "$domain_file"

    local final_count
    final_count=$(wc -l <"$domain_file")
    log_info "Final domain count: ${final_count}"

    if [[ "$OUT_TYPE" == "DNSMASQ_RULES" ]]; then
        log_info "Generating dnsmasq rules"
        cat >"$OUT_FILE" <<EOL
# dnsmasq rules generated by gfwlist2dnsmasq
# Last Updated: ${DATE_FORMAT}
# Total domains: ${final_count}
# Generated by: gfwlist2dnsmasq.sh v1.1.0
# ${SCRIPT_REPO}
#
# DNS Server: ${DNS_IP}#${DNS_PORT}
# Ipset: ${IPSET_NAME:-"(not used)"}

EOL

        if (( WITH_IPSET == 1 )); then
            awk -v dns="$DNS_IP" -v port="$DNS_PORT" -v ipset="$IPSET_NAME" \
                '{printf "server=/%s/%s#%s\nipset=/%s/%s\n", $0, dns, port, $0, ipset}' \
                "$domain_file" >>"$OUT_FILE"
        else
            awk -v dns="$DNS_IP" -v port="$DNS_PORT" \
                '{printf "server=/%s/%s#%s\n", $0, dns, port}' \
                "$domain_file" >>"$OUT_FILE"
        fi
    else
        log_info "Generating plain domain list"
        cp "$domain_file" "$OUT_FILE"
    fi

    log_success "Output written to ${OUT_FILE}"
}

main() {
    initialize_logging
    create_temp_root
    trap cleanup_temp_root EXIT
    setup_error_trap
    setup_platform_specific
    check_dependencies_detailed

    if [[ $# -eq 0 ]]; then
        log_error "No arguments provided"
        usage 1
    fi

    local start_time
    start_time=$(date +%s)

    get_args "$@"
    process_gfwlist

    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    log_success "Conversion completed in ${duration} seconds"
}

main "$@"
