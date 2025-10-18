#!/usr/bin/env bash

# Name:        gfwlist2dnsmasq.sh
# Description: A shell script which converts gfwlist into dnsmasq rules or domain lists
# Version:     1.0.0 (2025.05.24)
# Original Author: Cokebar Chi
# Original Website: https://github.com/cokebar
# Modified by: ruijzhan

# Fail fast and behave consistently across environments
set -euo pipefail

# Ensure consistent behavior across different environments
export LC_ALL=POSIX

# Track temporary directory for cleanup
TMP_DIR=''
USE_WGET=0
BASE64_DECODE=''
SED_ERES=''

# Terminal color definitions for better readability
readonly COLOR_RED=$'\033[1;31m'
readonly COLOR_GREEN=$'\033[1;32m'
readonly COLOR_YELLOW=$'\033[1;33m'
readonly COLOR_RESET=$'\033[0m'

# Print colored messages
log_info() {
    printf "[INFO] %b\n" "$1"
}

log_success() {
    printf "${COLOR_GREEN}[SUCCESS] %b${COLOR_RESET}\n" "$1"
}

log_warn() {
    printf "${COLOR_YELLOW}[WARNING] %b${COLOR_RESET}\n" "$1" >&2
}

log_error() {
    printf "${COLOR_RED}[ERROR] %b${COLOR_RESET}\n" "$1" >&2
}

# Legacy color functions for backward compatibility
_green() {
    printf "${COLOR_GREEN}%b${COLOR_RESET}" "$1"
}

_red() {
    printf "${COLOR_RED}%b${COLOR_RESET}" "$1"
}

_yellow() {
    printf "${COLOR_YELLOW}%b${COLOR_RESET}" "$1"
}

# Remove leftovers even on unexpected exits
cleanup() {
    if [[ -n "${TMP_DIR:-}" && -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
}

trap cleanup EXIT

# Display usage information and exit
usage() {
    cat <<-EOF

${COLOR_GREEN}GFWList to DNSMasq Converter${COLOR_RESET}

Description:  A shell script that converts GFWList into dnsmasq rules or domain lists
Version:      1.0.0 (2025-05-24)
Original:     https://github.com/cokebar/gfwlist2dnsmasq
Modified by:  ruijzhan

${COLOR_GREEN}Usage:${COLOR_RESET} sh gfwlist2dnsmasq.sh [options] -o FILE

${COLOR_GREEN}Options:${COLOR_RESET}
    -d, --dns <dns_ip>
                DNS IP address for the GfwList domains (Default: 127.0.0.1)
                Can be IPv4 or IPv6 address

    -p, --port <dns_port>
                DNS port for the GfwList domains (Default: 5353)

    -s, --ipset <ipset_name>
                Ipset name for the GfwList domains
                If not specified, ipset rules will not be generated

    -o, --output <FILE>
                Path to the output file (Required)

    -i, --insecure
                Force bypass certificate validation (insecure)

    -l, --domain-list
                Convert GfwList into a simple domain list instead of dnsmasq rules
                When this option is set, DNS IP/Port & ipset are not needed

    --exclude-domain-file <FILE>
                Exclude specific domains listed in the specified file
                File format: one domain per line

    --extra-domain-file <FILE>
                Include extra domains from the specified file
                This is processed after the exclude-domain-file
                File format: one domain per line

    -h, --help
                Display this help message

${COLOR_GREEN}Examples:${COLOR_RESET}
    # Generate dnsmasq rules with default DNS settings
    sh gfwlist2dnsmasq.sh -o gfwlist.conf

    # Generate a simple domain list
    sh gfwlist2dnsmasq.sh -l -o gfwlist.txt

    # Generate dnsmasq rules with custom DNS and ipset
    sh gfwlist2dnsmasq.sh -d 8.8.8.8 -p 53 -s gfwlist -o gfwlist.conf
EOF
    exit $1
}

# Check for required dependencies
check_depends() {
    log_info "Checking dependencies..."
    
    # Check for essential tools
    local missing_tools=false
    for tool in sed base64 mktemp grep awk sort; do
        if ! command -v $tool >/dev/null 2>&1; then
            log_error "Missing dependency: $tool"
            missing_tools=true
        fi
    done
    
    if $missing_tools; then
        log_error "Please install the missing dependencies and try again"
        exit 3
    fi
    
    # Check for download tools (curl or wget)
    if command -v curl >/dev/null 2>&1; then
        USE_WGET=0
        log_info "Using curl for downloads"
    elif command -v wget >/dev/null 2>&1; then
        USE_WGET=1
        log_info "Using wget for downloads"
    else
        log_error "Either curl or wget is required but neither was found"
        exit 3
    fi
    
    # Set system-specific commands
    SYS_KERNEL=$(uname -s)
    if [ "$SYS_KERNEL" = "Darwin" ] || [ "$SYS_KERNEL" = "FreeBSD" ]; then
        BASE64_DECODE='base64 -D'
        SED_ERES='sed -E'
        log_info "Detected $SYS_KERNEL system"
    else
        BASE64_DECODE='base64 -d'
        SED_ERES='sed -r'
        log_info "Detected Linux/Other system"
    fi
    
    log_success "All dependencies satisfied"
}

# Parse and validate command line arguments
get_args() {
    # Default values
    OUT_TYPE='DNSMASQ_RULES'
    DNS_IP='127.0.0.1'
    DNS_PORT='5353'
    IPSET_NAME=''
    OUT_FILE=''
    CURL_EXTARG=''
    WGET_EXTARG=''
    WITH_IPSET=0
    EXTRA_DOMAIN_FILE=''
    EXCLUDE_DOMAIN_FILE=''
    
    # IP address validation patterns
    local IPV4_PATTERN='^((2[0-4][0-9]|25[0-5]|[01]?[0-9][0-9]?)\.){3}(2[0-4][0-9]|25[0-5]|[01]?[0-9][0-9]?)$'
    local IPV6_PATTERN='^((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:)))(%.+)?$'
    
    log_info "Parsing command line arguments"
    
    # Parse command line arguments
    while [ $# -gt 0 ]; do
        case "${1}" in
            --help | -h)
                usage 0
                ;;
            --domain-list | -l)
                OUT_TYPE='DOMAIN_LIST'
                log_info "Output type set to domain list"
                ;;
            --insecure | -i)
                CURL_EXTARG='--insecure'
                WGET_EXTARG='--no-check-certificate'
                log_warn "Certificate validation disabled (insecure mode)"
                ;;
            --dns | -d)
                if [ $# -lt 2 ] || [[ ${2-} == -* ]]; then
                    log_error "Missing value for DNS IP parameter"
                    usage 1
                fi
                DNS_IP="$2"
                log_info "DNS IP set to $DNS_IP"
                shift
                ;;
            --port | -p)
                if [ $# -lt 2 ] || [[ ${2-} == -* ]]; then
                    log_error "Missing value for DNS port parameter"
                    usage 1
                fi
                DNS_PORT="$2"
                log_info "DNS port set to $DNS_PORT"
                shift
                ;;
            --ipset | -s)
                if [ $# -lt 2 ] || [[ ${2-} == -* ]]; then
                    log_error "Missing value for ipset parameter"
                    usage 1
                fi
                IPSET_NAME="$2"
                log_info "Ipset name set to $IPSET_NAME"
                shift
                ;;
            --output | -o)
                if [ $# -lt 2 ] || [[ ${2-} == -* ]]; then
                    log_error "Missing value for output file parameter"
                    usage 1
                fi
                OUT_FILE="$2"
                log_info "Output file set to $OUT_FILE"
                shift
                ;;
            --extra-domain-file)
                if [ $# -lt 2 ] || [[ ${2-} == -* ]]; then
                    log_error "Missing value for extra domain file parameter"
                    usage 1
                fi
                EXTRA_DOMAIN_FILE="$2"
                log_info "Extra domain file set to $EXTRA_DOMAIN_FILE"
                shift
                ;;
            --exclude-domain-file)
                if [ $# -lt 2 ] || [[ ${2-} == -* ]]; then
                    log_error "Missing value for exclude domain file parameter"
                    usage 1
                fi
                EXCLUDE_DOMAIN_FILE="$2"
                log_info "Exclude domain file set to $EXCLUDE_DOMAIN_FILE"
                shift
                ;;
            *)
                log_error "Invalid argument: $1"
                usage 1
                ;;
        esac
        shift 1
    done
    
    # Validate output file
    if [ -z "$OUT_FILE" ]; then
        log_error "No output file specified. Please use -o/--output to specify an output file."
        exit 1
    fi
    
    # Check if output path is valid
    if [ -z "${OUT_FILE##*/}" ]; then
        log_error "'$OUT_FILE' is a directory path, not a file path"
        exit 1
    fi
    
    # Check if parent directory exists
    if [ "${OUT_FILE}a" != "${OUT_FILE%/*}a" ] && [ ! -d "${OUT_FILE%/*}" ]; then
        log_error "Directory does not exist: ${OUT_FILE%/*}"
        exit 1
    fi
    
    # Validate parameters for DNSMASQ_RULES output type
    if [ "$OUT_TYPE" = "DNSMASQ_RULES" ]; then
        # Validate DNS IP
        if [[ ! $DNS_IP =~ $IPV4_PATTERN && ! $DNS_IP =~ $IPV6_PATTERN ]]; then
            log_error "Invalid DNS server IP address: $DNS_IP"
            exit 1
        fi

        # Validate DNS port
        if ! [[ $DNS_PORT =~ ^[0-9]+$ ]] || [ "$DNS_PORT" -lt 1 ] || [ "$DNS_PORT" -gt 65535 ]; then
            log_error "Invalid DNS port: $DNS_PORT (must be between 1-65535)"
            exit 1
        fi

        # Validate ipset name if provided
        if [ -n "$IPSET_NAME" ]; then
            if [[ $IPSET_NAME =~ ^[[:alnum:]_]+(,[[:alnum:]_]+)*$ ]]; then
                WITH_IPSET=1
                log_info "Ipset rules will be generated"
            else
                log_error "Invalid ipset name: $IPSET_NAME"
                exit 1
            fi
        else
            log_info "Ipset rules will not be generated"
        fi
    fi
    
    # Validate extra domain file if specified
    if [ -n "$EXTRA_DOMAIN_FILE" ]; then
        if [ ! -f "$EXTRA_DOMAIN_FILE" ]; then
            log_warn "Extra domain file does not exist: $EXTRA_DOMAIN_FILE (will be ignored)"
            EXTRA_DOMAIN_FILE=''
        else
            log_info "Extra domain file is valid"
        fi
    fi
    
    # Validate exclude domain file if specified
    if [ -n "$EXCLUDE_DOMAIN_FILE" ]; then
        if [ ! -f "$EXCLUDE_DOMAIN_FILE" ]; then
            log_warn "Exclude domain file does not exist: $EXCLUDE_DOMAIN_FILE (will be ignored)"
            EXCLUDE_DOMAIN_FILE=''
        else
            log_info "Exclude domain file is valid"
        fi
    fi
    
    log_success "All arguments validated successfully"
}

# Process GFWList and generate output files
process() {
    # Prepare working paths
    local base_url='https://github.com/gfwlist/gfwlist/raw/master/gfwlist.txt'
    TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/gfwlist2dnsmasq.XXXXXX")
    local base64_file="$TMP_DIR/base64.txt"
    local gfwlist_file="$TMP_DIR/gfwlist.txt"
    local domain_temp_file="$TMP_DIR/gfwlist2domain.tmp"
    local domain_file="$TMP_DIR/gfwlist2domain.txt"
    local out_tmp_file="$TMP_DIR/gfwlist.out.tmp"

    # Step 1: Fetch GFWList
    log_info "Fetching GFWList from $base_url"
    
    # Download with appropriate tool
    if [ $USE_WGET -eq 0 ]; then
        if ! curl -s -L --connect-timeout 30 --retry 3 $CURL_EXTARG -o "$base64_file" "$base_url"; then
            log_error "Failed to fetch gfwlist.txt using curl"
            log_error "Please check your internet connection and TLS support"
            exit 2
        fi
    else
        if ! wget -q --timeout=30 --tries=3 $WGET_EXTARG -O "$base64_file" "$base_url"; then
            log_error "Failed to fetch gfwlist.txt using wget"
            log_error "Please check your internet connection and TLS support"
            exit 2
        fi
    fi

    # Decode base64 content
    log_info "Decoding base64 content"
    if ! $BASE64_DECODE "$base64_file" > "$gfwlist_file"; then
        log_error "Failed to decode gfwlist.txt"
        exit 2
    fi
    
    log_success "GFWList fetched and decoded successfully"
    
    # Step 2: Extract domains from GFWList
    log_info "Extracting domains from GFWList"
    
    # Define patterns for filtering
    IGNORE_PATTERN='^\!|\[|^@@|(https?://){0,1}[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+'
    HEAD_FILTER_PATTERN='s#^(\|\|?)?(https?://)?##g'
    TAIL_FILTER_PATTERN='s#/.*$|%2F.*$##g'
    DOMAIN_PATTERN='([a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)+)'
    HANDLE_WILDCARD_PATTERN='s#^(([a-zA-Z0-9]*\*[-a-zA-Z0-9]*)?(\.))?([a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)+)(\*[a-zA-Z0-9]*)?#\4#g'
    
    # Extract domains using patterns
    log_info "Filtering and processing domains"
    set +e
    grep -vE "$IGNORE_PATTERN" "$gfwlist_file" | \
        $SED_ERES "$HEAD_FILTER_PATTERN" | \
        $SED_ERES "$TAIL_FILTER_PATTERN" | \
        grep -E "$DOMAIN_PATTERN" | \
        $SED_ERES "$HANDLE_WILDCARD_PATTERN" > "$domain_temp_file"
    local pipeline_status=$?
    set -e
    if [ $pipeline_status -ne 0 ]; then
        log_warn "Domain extraction pipeline returned status $pipeline_status"
    fi

    # Count extracted domains
    local extracted_count
    extracted_count=$(wc -l < "$domain_temp_file")
    log_info "Extracted $extracted_count domains from GFWList"
    
      
    # Step 3: Apply exclude and include domain lists
    
    # Handle exclude domains if specified
    if [ -n "$EXCLUDE_DOMAIN_FILE" ]; then
        log_info "Applying exclude domain list from $EXCLUDE_DOMAIN_FILE"
        local before_count
        before_count=$(wc -l < "$domain_temp_file")
        if grep -vF -f "$EXCLUDE_DOMAIN_FILE" "$domain_temp_file" > "$domain_file"; then
            :
        else
            : > "$domain_file"
            log_warn "All domains were excluded by $EXCLUDE_DOMAIN_FILE"
        fi
        local after_count
        after_count=$(wc -l < "$domain_file")
        local excluded_count=$((before_count - after_count))
        log_info "Excluded $excluded_count domains"
    else
        cp "$domain_temp_file" "$domain_file"
    fi

    # Add extra domains if specified
    if [ -n "$EXTRA_DOMAIN_FILE" ]; then
        log_info "Adding extra domains from $EXTRA_DOMAIN_FILE"
        local extra_count
        extra_count=$(grep -cv '^[[:space:]]*$' "$EXTRA_DOMAIN_FILE" || true)
        if [ "${extra_count:-0}" -gt 0 ]; then
            grep -v '^[[:space:]]*$' "$EXTRA_DOMAIN_FILE" >> "$domain_file" || true
            log_info "Added $extra_count extra domains"
        else
            log_warn "Extra domain file $EXTRA_DOMAIN_FILE is empty after filtering"
        fi
    fi
    
    # Step 4: Generate output file based on output type
    log_info "Generating $OUT_TYPE output"
    
    # Sort and remove duplicates
    LC_ALL=POSIX sort -u "$domain_file" -o "$domain_file"
    
    # Count final domains
    local final_count
    final_count=$(wc -l < "$domain_file")
    log_info "Final domain count: $final_count"
    
    if [ "$OUT_TYPE" = "DNSMASQ_RULES" ]; then
        # Generate dnsmasq rules
        log_info "Generating dnsmasq rules"
        
        # Create header for the output file
        cat > "$out_tmp_file" << EOL
# dnsmasq rules generated by gfwlist2dnsmasq
# Last Updated: $(date "+%Y-%m-%d %H:%M:%S")
# Total domains: $final_count
# Generated by: gfwlist2dnsmasq.sh v1.0.0
# https://github.com/ruijzhan/chnroute
#
# DNS Server: $DNS_IP#$DNS_PORT
# Ipset: ${IPSET_NAME:-"(not used)"}

EOL
        
        # Generate rules with or without ipset
        if [ $WITH_IPSET -eq 1 ]; then
            log_info "Including ipset rules for $IPSET_NAME"
            awk -v dns="$DNS_IP" -v port="$DNS_PORT" -v ipset="$IPSET_NAME" \
                '{printf "server=/%s/%s#%s\nipset=/%s/%s\n", $0, dns, port, $0, ipset}' \
                "$domain_file" >> "$out_tmp_file"
        else
            log_info "Ipset rules not included"
            awk -v dns="$DNS_IP" -v port="$DNS_PORT" \
                '{printf "server=/%s/%s#%s\n", $0, dns, port}' \
                "$domain_file" >> "$out_tmp_file"
        fi
    else
        # Generate simple domain list
        log_info "Generating simple domain list"
        cp "$domain_file" "$out_tmp_file"
    fi

    # Step 5: Write to output file
    cp "$out_tmp_file" "$OUT_FILE"
    log_success "Successfully generated $OUT_TYPE to $OUT_FILE with $final_count domains"
}

# Main function to coordinate script execution
main() {
    # Display banner
    printf "\n${COLOR_GREEN}GFWList to DNSMasq Converter v1.0.0${COLOR_RESET}\n"
    printf "${COLOR_GREEN}===============================${COLOR_RESET}\n\n"
    
    # Check for help argument first
    for arg in "$@"; do
        if [ "$arg" = "-h" ] || [ "$arg" = "--help" ]; then
            usage 0
        fi
    done
    
    # Show usage if no arguments provided
    if [ -z "$1" ]; then
        log_error "No arguments provided"
        usage 1
    fi
    
    # Start time tracking
    local start_time
    start_time=$(date +%s)
    
    # Execute the main workflow
    log_info "Starting GFWList to DNSMasq conversion"
    
    # Check dependencies
    check_depends
    
    # Parse arguments
    get_args "$@"
    
    # Process GFWList and generate output
    process
    
    # Calculate execution time
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    log_success "Conversion completed in $duration seconds"
    return 0
}

# Execute the main function with all arguments
main "$@"
