#!/usr/bin/env bash

set -euo pipefail

export LC_ALL=POSIX

# Constants
declare -r GFWLIST2DNSMASQ_SH="gfwlist2dnsmasq.sh"
declare -r INCLUDE_LIST_TXT="include_list.txt"
declare -r EXCLUDE_LIST_TXT="exclude_list.txt"
declare -r GFWLIST="gfwlist.txt"
declare -r LIST_NAME="gfw_list"
declare -r DNS_SERVER="\$dnsserver"
declare -r DNS_SERVER_VAR="dnsserver"
declare -r GFWLIST_RSC="gfwlist.rsc"
declare -r GFWLIST_V7_RSC="gfwlist_v7.rsc"
declare -r CN_RSC="CN.rsc"
declare -r GFWLIST_CONF="03-gfwlist.conf"
declare -r CN_URL="http://www.iwik.org/ipcountry/mikrotik/CN"

declare -r GFWLIST_URL="https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt"
declare -r OUTPUT_GFWLIST_AUTOPROXY="gfwlist_autoproxy.txt"

# Function to sort files
sort_files() {
    sort -uo "$INCLUDE_LIST_TXT" "$INCLUDE_LIST_TXT"
    sort -uo "$EXCLUDE_LIST_TXT" "$EXCLUDE_LIST_TXT"
}

# Function to run gfwlist2dnsmasq
run_gfwlist2dnsmasq() {
    bash "$GFWLIST2DNSMASQ_SH" -l --extra-domain-file "$INCLUDE_LIST_TXT" --exclude-domain-file "$EXCLUDE_LIST_TXT" -o "$GFWLIST"
}

# Function to create gfwlist resource script
create_gfwlist_rsc() {
    local version=$1
    local output_rsc=$2

    cp "$GFWLIST" "$output_rsc"

    local sed_script
    if [[ "$version" == "v7" ]]; then
        sed_script="
            s/$/ } on-error={}/g;
            s/^/:do { add forward-to=${DNS_SERVER} type=FWD address-list=${LIST_NAME} match-subdomain=yes name=/g;
            1s/^/\/ip dns static\n/;
            1s/^/\/ip dns static remove [\/ip dns static find forward-to=${DNS_SERVER} ]\n/;
            1s/^/:global ${DNS_SERVER_VAR}\n/
        "
    else
        sed_script="
            s/\./\\\\\\\\./g;
            s/$/\\\\$\" } on-error={}/g;
            s/^/:do { add forward-to=${DNS_SERVER} type=FWD address-list=${LIST_NAME} regexp=\".*/g;
            1s/^/\/ip dns static\n/;
            1s/^/\/ip dns static remove [\/ip dns static find forward-to=${DNS_SERVER} ]\n/;
            1s/^/:global ${DNS_SERVER_VAR}\n/
        "
    fi

    sed -i "$sed_script" "$output_rsc"
    echo "/ip dns cache flush" >> "$output_rsc"
}

# Function to check git status
check_git_status() {
    if [[ $(git status -s | wc -l) -eq 1 ]]; then
        git checkout "$GFWLIST_CONF"
    fi
}

# Function to download CN.rsc
download_cn_rsc() {
    if ! curl -sS -o "$CN_RSC" -w "%{http_code}" "$CN_URL" | grep -q '^2'; then
        echo 'Error: failed to download CN.rsc' >&2
        return 1
    fi
}

# Function to download and decode gfwlist
download_gfwlist() {
    if ! curl -s "$GFWLIST_URL" | base64 --decode > "$OUTPUT_GFWLIST_AUTOPROXY"; then
        echo "Error: failed to download or decode gfwlist" >&2
        return 1
    fi

    echo "Decoded content saved to $OUTPUT_GFWLIST_AUTOPROXY"
}

# Main execution
main() {
    sort_files
    run_gfwlist2dnsmasq
    create_gfwlist_rsc "default" "$GFWLIST_RSC"
    create_gfwlist_rsc "v7" "$GFWLIST_V7_RSC"
    check_git_status
    download_cn_rsc
    download_gfwlist
}

main
