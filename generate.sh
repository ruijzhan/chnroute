#!/usr/bin/env bash

set -euo pipefail

export LC_ALL=POSIX

# Constants
GFWLIST2DNSMASQ_SH="gfwlist2dnsmasq.sh"
INCLUDE_LIST_TXT="include_list.txt"
EXCLUDE_LIST_TXT="exclude_list.txt"
GFWLIST="gfwlist.txt"
LIST_NAME="gfw_list"
DNS_SERVER="\$dnsserver"
DNS_SERVER_VAR="dnsserver"
GFWLIST_RSC="gfwlist.rsc"
GFWLIST_V7_RSC="gfwlist_v7.rsc"
CN_RSC="CN.rsc"
GFWLIST_CONF="03-gfwlist.conf"
CN_URL="http://www.iwik.org/ipcountry/mikrotik/CN"

# Function to sort files
sort_files() {
    sort -o "$INCLUDE_LIST_TXT" "$INCLUDE_LIST_TXT"
    sort -o "$EXCLUDE_LIST_TXT" "$EXCLUDE_LIST_TXT"
}

# Function to run gfwlist2dnsmasq
run_gfwlist2dnsmasq() {
    sh "$GFWLIST2DNSMASQ_SH" -l --extra-domain-file "$INCLUDE_LIST_TXT" --exclude-domain-file "$EXCLUDE_LIST_TXT" -o "$GFWLIST"
}

# Function to create gfwlist resource script
create_gfwlist_rsc() {
    local version=$1
    local output_rsc=$2

    cp "$GFWLIST" "$output_rsc"

    # Use a case statement to differentiate between versions
    case "$version" in
        v7)
            sed -i "
                s/$/ } on-error={}/g;
                s/^/:do { add forward-to=${DNS_SERVER} type=FWD address-list=${LIST_NAME} match-subdomain=yes name=/g;
                1s/^/\/ip dns static\n/;
                1s/^/\/ip dns static remove [\/ip dns static find forward-to=${DNS_SERVER} ]\n/;
                1s/^/:global ${DNS_SERVER_VAR}\n/
                " "$output_rsc"
            ;;
        *)
            sed -i "
                s/\./\\\\\\\\./g;
                s/$/\\\\$\" } on-error={}/g;
                s/^/:do { add forward-to=${DNS_SERVER} type=FWD address-list=${LIST_NAME} regexp=\".*/g;
                1s/^/\/ip dns static\n/;
                1s/^/\/ip dns static remove [\/ip dns static find forward-to=${DNS_SERVER} ]\n/;
                1s/^/:global ${DNS_SERVER_VAR}\n/
                " "$output_rsc"
            ;;
    esac

    sed -i -e '$a\/ip dns cache flush' "$output_rsc"
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
    local url="https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt"
    local output_file="gfwlist_autoproxy.txt"

    if ! curl -s "$url" | base64 --decode > "$output_file"; then
        echo "Error: failed to download or decode gfwlist" >&2
        return 1
    fi

    echo "Decoded content saved to $output_file"
}

# Main execution
sort_files
run_gfwlist2dnsmasq
create_gfwlist_rsc "default" "$GFWLIST_RSC"
create_gfwlist_rsc "v7" "$GFWLIST_V7_RSC"
check_git_status
download_cn_rsc
download_gfwlist
