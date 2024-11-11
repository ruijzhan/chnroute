#!/usr/bin/env bash

set -euo pipefail

export LC_ALL=POSIX

readonly GFWLIST2DNSMASQ_SH="gfwlist2dnsmasq.sh"
readonly INCLUDE_LIST_TXT="include_list.txt"
readonly EXCLUDE_LIST_TXT="exclude_list.txt"
readonly GFWLIST="gfwlist.txt"
readonly LIST_NAME="gfw_list"
readonly DNS_SERVER="\$dnsserver"
readonly GFWLIST_V7_RSC="gfwlist_v7.rsc"
readonly CN_RSC="CN.rsc"
readonly CN_IN_MEM_RSC="CN_mem.rsc"
readonly GFWLIST_CONF="03-gfwlist.conf"
readonly CN_URL="http://www.iwik.org/ipcountry/mikrotik/CN"
readonly GFWLIST_URL="https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt"
readonly OUTPUT_GFWLIST_AUTOPROXY="gfwlist_autoproxy.txt"

# print info message
log_info() {
    printf "[INFO] %s\n" "$1"
}

# print error message
log_error() {
    printf "[ERROR] %s\n" "$1" >&2
}

# sort include and exclude domain lists
sort_files() {
    log_info "Sorting include and exclude domain lists..."
    sort -uo "$INCLUDE_LIST_TXT" "$INCLUDE_LIST_TXT"
    sort -uo "$EXCLUDE_LIST_TXT" "$EXCLUDE_LIST_TXT"
}

# run gfwlist2dnsmasq to generate gfwlist
run_gfwlist2dnsmasq() {
    log_info "Running gfwlist2dnsmasq..."
    bash "$GFWLIST2DNSMASQ_SH" \
        --domain-list \
        --extra-domain-file "$INCLUDE_LIST_TXT" \
        --exclude-domain-file "$EXCLUDE_LIST_TXT" \
        --output "$GFWLIST"
}

# create gfwlist rsc file
create_gfwlist_rsc() {
    local version="$1"
    local output_rsc="$2"
    local input_file="$GFWLIST"
    log_info "Creating $output_rsc for version $version..."

    cat <<EOL >"$output_rsc"
:global dnsserver
/ip dns static remove [/ip dns static find forward-to=\$dnsserver ]
/ip dns static
:local domainList {
EOL

    while read -r line; do
        echo "    \"$line\";" >>"$output_rsc"
    done <"$input_file"

    cat <<EOL >>"$output_rsc"
}
:foreach domain in=\$domainList do={
    /ip dns static add forward-to=\$dnsserver type=FWD address-list=gfw_list match-subdomain=yes name=\$domain
}
EOL

    echo "/ip dns cache flush" >>"$output_rsc"
}

# check if there are any changes in the git repository
check_git_status() {
    log_info "Checking git status..."
    if [[ $(git status -s | wc -l) -eq 1 ]]; then
        git checkout "$GFWLIST_CONF"
    fi
}

generate_cn_ip_list() {
    local input_file="$1"
    local output_file="$2"
    local timeout="$3"

    # Check the number of parameters
    if [ "$#" -ne 3 ]; then
        echo "Usage: generate_cn_ip_list <input file> <output file> <timeout>"
        return 1
    fi

    # If the input file and output file are the same, use a temporary file
    local tmp_file
    if [ "$input_file" == "$output_file" ]; then
        tmp_file=$(mktemp)
    else
        tmp_file="$output_file"
    fi

    # Use heredoc to write the initial part to the temporary file
    cat <<EOL > "$tmp_file"
/log info "Loading CN ipv4 address list"
/ip firewall address-list remove [/ip firewall address-list find list=CN]
/ip firewall address-list
:local ipList {
EOL

    # Read the input file, extract IP addresses and subnets, and write them to ipList
    sed -n 's/.*address=\([0-9./]\+\).*/    "\1";/p' "$input_file" >> "$tmp_file"

    # Write the loop part to the temporary file
    cat <<EOL >> "$tmp_file"
}
:foreach ip in=\$ipList do={
    /ip firewall address-list add address=\$ip list=CN timeout=$timeout
}
EOL

    # If a temporary file was used, move it to the output file
    if [ "$tmp_file" != "$output_file" ]; then
        mv "$tmp_file" "$output_file"
    fi

    echo "Conversion complete! The generated file is $output_file"
}

# modify CN.rsc to change the timeout
modify_cn_rsc() {
    local input_file="$CN_RSC"
    local output_file="$CN_IN_MEM_RSC"
    
    generate_cn_ip_list "$input_file" "$output_file" "248d"
    generate_cn_ip_list "$input_file" "$input_file" "0"
    log_info "New file created: $output_file"
}

# download CN.rsc
download_cn_rsc() {
    log_info "Downloading CN.rsc..."
    if ! curl -sS -o "$CN_RSC" -w "%{http_code}" "$CN_URL" | grep -q '^2'; then
        log_error "Failed to download CN.rsc"
        return 1
    fi

    modify_cn_rsc
}

# download and decode gfwlist
download_gfwlist() {
    log_info "Downloading and decoding gfwlist..."
    if ! curl -s "$GFWLIST_URL" | base64 --decode >"$OUTPUT_GFWLIST_AUTOPROXY"; then
        log_error "Failed to download or decode gfwlist"
        return 1
    fi

    log_info "Decoded content saved to $OUTPUT_GFWLIST_AUTOPROXY"
}

main() {
    sort_files
    run_gfwlist2dnsmasq
    create_gfwlist_rsc "v7" "$GFWLIST_V7_RSC"
    check_git_status
    download_cn_rsc
    download_gfwlist
}

main