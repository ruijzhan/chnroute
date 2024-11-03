#!/usr/bin/env bash

set -euo pipefail

export LC_ALL=POSIX

readonly GFWLIST2DNSMASQ_SH="gfwlist2dnsmasq.sh"
readonly FOR_LOOP_CN_SH="for_loop_cn.sh"
readonly INCLUDE_LIST_TXT="include_list.txt"
readonly EXCLUDE_LIST_TXT="exclude_list.txt"
readonly GFWLIST="gfwlist.txt"
readonly LIST_NAME="gfw_list"
readonly DNS_SERVER="\$dnsserver"
readonly DNS_SERVER_VAR="dnsserver"
readonly GFWLIST_RSC="gfwlist.rsc"
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
    log_info "Creating $output_rsc for version $version..."

    cp "$GFWLIST" "$output_rsc"

    local sed_script
    if [[ "$version" == "v7" ]]; then
        sed_script="s/$/ } on-error={}/g;
                    s/^/:do { add forward-to=${DNS_SERVER} type=FWD address-list=${LIST_NAME} match-subdomain=yes name=/g;
                    1s/^/\/ip dns static\n/;
                    1s/^/\/ip dns static remove [\/ip dns static find forward-to=${DNS_SERVER} ]\n/;
                    1s/^/:global ${DNS_SERVER_VAR}\n/"
    else
        sed_script="s/\./\\\\\\\\./g;
                    s/$/\\\\$\" } on-error={}/g;
                    s/^/:do { add forward-to=${DNS_SERVER} type=FWD address-list=${LIST_NAME} regexp=\".*/g;
                    1s/^/\/ip dns static\n/;
                    1s/^/\/ip dns static remove [\/ip dns static find forward-to=${DNS_SERVER} ]\n/;
                    1s/^/:global ${DNS_SERVER_VAR}\n/"
    fi

    sed -i "$sed_script" "$output_rsc"
    echo "/ip dns cache flush" >>"$output_rsc"
}

# check if there are any changes in the git repository
check_git_status() {
    log_info "Checking git status..."
    if [[ $(git status -s | wc -l) -eq 1 ]]; then
        git checkout "$GFWLIST_CONF"
    fi
}

# modify CN.rsc to change the timeout
modify_cn_rsc() {
    local input_file="$CN_RSC"
    local output_file="$CN_IN_MEM_RSC"
    local tmp_fime="tmp_file"

    bash "$FOR_LOOP_CN_SH" "$input_file" "$output_file" "248d"
    bash "$FOR_LOOP_CN_SH" "$input_file" "$tmp_fime" "0"
    mv "$tmp_fime" "$input_file"

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
    create_gfwlist_rsc "default" "$GFWLIST_RSC"
    create_gfwlist_rsc "v7" "$GFWLIST_V7_RSC"
    check_git_status
    download_cn_rsc
    download_gfwlist
}

main

