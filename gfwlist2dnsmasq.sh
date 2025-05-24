#!/bin/sh

# Name:        gfwlist2dnsmasq.sh
# Description: A shell script which converts gfwlist into dnsmasq rules or domain lists
# Version:     1.0.0 (2025.05.24)
# Original Author: Cokebar Chi
# Original Website: https://github.com/cokebar
# Modified by: ruijzhan

# Ensure consistent behavior across different environments
export LC_ALL=POSIX

# Terminal color definitions for better readability
COLOR_RED='\033[1;31m'
COLOR_GREEN='\033[1;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_RESET='\033[0m'

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

# Clean up temporary files and exit with status code
clean_and_exit() {
    local exit_code=$1
    
    # Clean up temp files
    log_info "Cleaning up temporary files..."
    if [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
        log_success "Temporary directory removed"
    fi
    
    # Print exit message based on exit code
    if [ $exit_code -eq 0 ]; then
        log_success "Job completed successfully"
    else
        log_error "Job failed with exit code $exit_code"
    fi
    
    exit $exit_code
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
    IPV4_PATTERN='^((2[0-4][0-9]|25[0-5]|[01]?[0-9][0-9]?)\.){3}(2[0-4][0-9]|25[0-5]|[01]?[0-9][0-9]?)$'
    IPV6_PATTERN='^((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])(\.(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])){3}))|:)))(%.+)?$'
    
    log_info "Parsing command line arguments"
    
    # Parse command line arguments
    while [ ${#} -gt 0 ]; do
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
                if [ -z "$2" ] || [ "${2:0:1}" = "-" ]; then
                    log_error "Missing value for DNS IP parameter"
                    usage 1
                fi
                DNS_IP="$2"
                log_info "DNS IP set to $DNS_IP"
                shift
                ;;
            --port | -p)
                if [ -z "$2" ] || [ "${2:0:1}" = "-" ]; then
                    log_error "Missing value for DNS port parameter"
                    usage 1
                fi
                DNS_PORT="$2"
                log_info "DNS port set to $DNS_PORT"
                shift
                ;;
            --ipset | -s)
                if [ -z "$2" ] || [ "${2:0:1}" = "-" ]; then
                    log_error "Missing value for ipset parameter"
                    usage 1
                fi
                IPSET_NAME="$2"
                log_info "Ipset name set to $IPSET_NAME"
                shift
                ;;
            --output | -o)
                if [ -z "$2" ] || [ "${2:0:1}" = "-" ]; then
                    log_error "Missing value for output file parameter"
                    usage 1
                fi
                OUT_FILE="$2"
                log_info "Output file set to $OUT_FILE"
                shift
                ;;
            --extra-domain-file)
                if [ -z "$2" ] || [ "${2:0:1}" = "-" ]; then
                    log_error "Missing value for extra domain file parameter"
                    usage 1
                fi
                EXTRA_DOMAIN_FILE="$2"
                log_info "Extra domain file set to $EXTRA_DOMAIN_FILE"
                shift
                ;;
            --exclude-domain-file)
                if [ -z "$2" ] || [ "${2:0:1}" = "-" ]; then
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
        IPV4_TEST=$(echo "$DNS_IP" | grep -E "$IPV4_PATTERN")
        IPV6_TEST=$(echo "$DNS_IP" | grep -E "$IPV6_PATTERN")
        if [ "$IPV4_TEST" != "$DNS_IP" ] && [ "$IPV6_TEST" != "$DNS_IP" ]; then
            log_error "Invalid DNS server IP address: $DNS_IP"
            exit 1
        fi
        
        # Validate DNS port
        if ! echo "$DNS_PORT" | grep -qE '^[0-9]+$' || [ "$DNS_PORT" -lt 1 ] || [ "$DNS_PORT" -gt 65535 ]; then
            log_error "Invalid DNS port: $DNS_PORT (must be between 1-65535)"
            exit 1
        fi
        
        # Validate ipset name if provided
        if [ -n "$IPSET_NAME" ]; then
            IPSET_TEST=$(echo "$IPSET_NAME" | grep -E '^\w+(,\w+)*$')
            if [ "$IPSET_TEST" != "$IPSET_NAME" ]; then
                log_error "Invalid ipset name: $IPSET_NAME"
                exit 1
            else
                WITH_IPSET=1
                log_info "Ipset rules will be generated"
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
    # Set global variables
    BASE_URL='https://github.com/gfwlist/gfwlist/raw/master/gfwlist.txt'
    TMP_DIR=$(mktemp -d /tmp/gfwlist2dnsmasq.XXXXXX)
    BASE64_FILE="$TMP_DIR/base64.txt"
    GFWLIST_FILE="$TMP_DIR/gfwlist.txt"
    DOMAIN_TEMP_FILE="$TMP_DIR/gfwlist2domain.tmp"
    DOMAIN_FILE="$TMP_DIR/gfwlist2domain.txt"
    CONF_TMP_FILE="$TMP_DIR/gfwlist.conf.tmp"
    OUT_TMP_FILE="$TMP_DIR/gfwlist.out.tmp"
    GOOGLE_DOMAINS_FILE="$TMP_DIR/google_domains.txt"
    BLOGSPOT_DOMAINS_FILE="$TMP_DIR/blogspot_domains.txt"
    
    # Step 1: Fetch GFWList
    log_info "Fetching GFWList from $BASE_URL"
    
    # Download with appropriate tool
    if [ $USE_WGET -eq 0 ]; then
        if ! curl -s -L --connect-timeout 30 --retry 3 $CURL_EXTARG -o "$BASE64_FILE" "$BASE_URL"; then
            log_error "Failed to fetch gfwlist.txt using curl"
            log_error "Please check your internet connection and TLS support"
            clean_and_exit 2
        fi
    else
        if ! wget -q --timeout=30 --tries=3 $WGET_EXTARG -O "$BASE64_FILE" "$BASE_URL"; then
            log_error "Failed to fetch gfwlist.txt using wget"
            log_error "Please check your internet connection and TLS support"
            clean_and_exit 2
        fi
    fi
    
    # Decode base64 content
    log_info "Decoding base64 content"
    if ! $BASE64_DECODE "$BASE64_FILE" > "$GFWLIST_FILE"; then
        log_error "Failed to decode gfwlist.txt"
        clean_and_exit 2
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
    grep -vE "$IGNORE_PATTERN" "$GFWLIST_FILE" | \
        $SED_ERES "$HEAD_FILTER_PATTERN" | \
        $SED_ERES "$TAIL_FILTER_PATTERN" | \
        grep -E "$DOMAIN_PATTERN" | \
        $SED_ERES "$HANDLE_WILDCARD_PATTERN" > "$DOMAIN_TEMP_FILE"
    
    # Count extracted domains
    local extracted_count
    extracted_count=$(wc -l < "$DOMAIN_TEMP_FILE")
    log_info "Extracted $extracted_count domains from GFWList"
    
    # Step 3: Add additional domains
    log_info "Adding additional domain lists"
    
    # Create Google domains file
    cat > "$GOOGLE_DOMAINS_FILE" << 'EOL'
google.com
google.ad
google.ae
google.com.af
google.com.ag
google.com.ai
google.al
google.am
google.co.ao
google.com.ar
google.as
google.at
google.com.au
google.az
google.ba
google.com.bd
google.be
google.bf
google.bg
google.com.bh
google.bi
google.bj
google.com.bn
google.com.bo
google.com.br
google.bs
google.bt
google.co.bw
google.by
google.com.bz
google.ca
google.cd
google.cf
google.cg
google.ch
google.ci
google.co.ck
google.cl
google.cm
google.cn
google.com.co
google.co.cr
google.com.cu
google.cv
google.com.cy
google.cz
google.de
google.dj
google.dk
google.dm
google.com.do
google.dz
google.com.ec
google.ee
google.com.eg
google.es
google.com.et
google.fi
google.com.fj
google.fm
google.fr
google.ga
google.ge
google.gg
google.com.gh
google.com.gi
google.gl
google.gm
google.gp
google.gr
google.com.gt
google.gy
google.com.hk
google.hn
google.hr
google.ht
google.hu
google.co.id
google.ie
google.co.il
google.im
google.co.in
google.iq
google.is
google.it
google.je
google.com.jm
google.jo
google.co.jp
google.co.ke
google.com.kh
google.ki
google.kg
google.co.kr
google.com.kw
google.kz
google.la
google.com.lb
google.li
google.lk
google.co.ls
google.lt
google.lu
google.lv
google.com.ly
google.co.ma
google.md
google.me
google.mg
google.mk
google.ml
google.com.mm
google.mn
google.ms
google.com.mt
google.mu
google.mv
google.mw
google.com.mx
google.com.my
google.co.mz
google.com.na
google.com.nf
google.com.ng
google.com.ni
google.ne
google.nl
google.no
google.com.np
google.nr
google.nu
google.co.nz
google.com.om
google.com.pa
google.com.pe
google.com.pg
google.com.ph
google.com.pk
google.pl
google.pn
google.com.pr
google.ps
google.pt
google.com.py
google.com.qa
google.ro
google.ru
google.rw
google.com.sa
google.com.sb
google.sc
google.se
google.com.sg
google.sh
google.si
google.sk
google.com.sl
google.sn
google.so
google.sm
google.sr
google.st
google.com.sv
google.td
google.tg
google.co.th
google.com.tj
google.tk
google.tl
google.tm
google.tn
google.to
google.com.tr
google.tt
google.com.tw
google.co.tz
google.com.ua
google.co.ug
google.co.uk
google.com.uy
google.co.uz
google.com.vc
google.co.ve
google.vg
google.co.vi
google.com.vn
google.vu
google.ws
google.rs
google.co.za
google.co.zm
google.co.zw
google.cat
EOL
    
    # Create Blogspot domains file
    cat > "$BLOGSPOT_DOMAINS_FILE" << 'EOL'
blogspot.ca
blogspot.co.uk
blogspot.com
blogspot.com.ar
blogspot.com.au
blogspot.com.br
blogspot.com.by
blogspot.com.co
blogspot.com.cy
blogspot.com.ee
blogspot.com.eg
blogspot.com.es
blogspot.com.mt
blogspot.com.ng
blogspot.com.tr
blogspot.com.uy
blogspot.de
blogspot.gr
blogspot.in
blogspot.mx
blogspot.ch
blogspot.fr
blogspot.ie
blogspot.it
blogspot.pt
blogspot.ro
blogspot.sg
blogspot.be
blogspot.no
blogspot.se
blogspot.jp
blogspot.in
blogspot.ae
blogspot.al
blogspot.am
blogspot.ba
blogspot.bg
blogspot.ch
blogspot.cl
blogspot.cz
blogspot.dk
blogspot.fi
blogspot.gr
blogspot.hk
blogspot.hr
blogspot.hu
blogspot.ie
blogspot.is
blogspot.kr
blogspot.li
blogspot.lt
blogspot.lu
blogspot.md
blogspot.mk
blogspot.my
blogspot.nl
blogspot.no
blogspot.pe
blogspot.qa
blogspot.ro
blogspot.ru
blogspot.se
blogspot.sg
blogspot.si
blogspot.sk
blogspot.sn
blogspot.tw
blogspot.ug
blogspot.cat
EOL
    
    # Add Google domains
    cat "$GOOGLE_DOMAINS_FILE" >> "$DOMAIN_TEMP_FILE"
    log_info "Added Google search domains"
    
    # Add Blogspot domains
    cat "$BLOGSPOT_DOMAINS_FILE" >> "$DOMAIN_TEMP_FILE"
    log_info "Added Blogspot domains"
    
    # Add other special domains
    echo "twimg.edgesuite.net" >> "$DOMAIN_TEMP_FILE"
    log_info "Added additional special domains"
    
    # Step 4: Apply exclude and include domain lists
    
    # Handle exclude domains if specified
    if [ -n "$EXCLUDE_DOMAIN_FILE" ]; then
        log_info "Applying exclude domain list from $EXCLUDE_DOMAIN_FILE"
        grep -vF -f "$EXCLUDE_DOMAIN_FILE" "$DOMAIN_TEMP_FILE" > "$DOMAIN_FILE"
        local excluded_count
        excluded_count=$(wc -l < "$EXCLUDE_DOMAIN_FILE")
        log_info "Excluded $excluded_count domains"
    else
        cp "$DOMAIN_TEMP_FILE" "$DOMAIN_FILE"
    fi
    
    # Add extra domains if specified
    if [ -n "$EXTRA_DOMAIN_FILE" ]; then
        log_info "Adding extra domains from $EXTRA_DOMAIN_FILE"
        cat "$EXTRA_DOMAIN_FILE" >> "$DOMAIN_FILE"
        local extra_count
        extra_count=$(wc -l < "$EXTRA_DOMAIN_FILE")
        log_info "Added $extra_count extra domains"
    fi
    
    # Step 5: Generate output file based on output type
    log_info "Generating $OUT_TYPE output"
    
    # Sort and remove duplicates
    sort -u "$DOMAIN_FILE" > "$OUT_TMP_FILE.sorted"
    mv "$OUT_TMP_FILE.sorted" "$DOMAIN_FILE"
    
    # Count final domains
    local final_count
    final_count=$(wc -l < "$DOMAIN_FILE")
    log_info "Final domain count: $final_count"
    
    if [ "$OUT_TYPE" = "DNSMASQ_RULES" ]; then
        # Generate dnsmasq rules
        log_info "Generating dnsmasq rules"
        
        # Create header for the output file
        cat > "$OUT_TMP_FILE" << EOL
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
                "$DOMAIN_FILE" >> "$OUT_TMP_FILE"
        else
            log_info "Ipset rules not included"
            awk -v dns="$DNS_IP" -v port="$DNS_PORT" \
                '{printf "server=/%s/%s#%s\n", $0, dns, port}' \
                "$DOMAIN_FILE" >> "$OUT_TMP_FILE"
        fi
    else
        # Generate simple domain list
        log_info "Generating simple domain list"
        cp "$DOMAIN_FILE" "$OUT_TMP_FILE"
    fi
    
    # Step 6: Write to output file
    cp "$OUT_TMP_FILE" "$OUT_FILE"
    log_success "Successfully generated $OUT_TYPE to $OUT_FILE with $final_count domains"
    
    # Clean up and exit
    clean_and_exit 0
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
