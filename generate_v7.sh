#!/bin/bash

set -euo pipefail  # Enable error handling and logging

# Define constants
GFWLIST2DNSMASQ_SH="gfwlist2dnsmasq.sh"
INCLUDE_LIST_TXT="include_list.txt"
EXCLUDE_LIST_TXT="exclude_list.txt"
TMP="tmp"
GFWLIST_V7_RSC="gfwlist_v7.rsc"
GFW_LIST="gfw_list"
DNS_SERVER="\$dnsserver"
DNS_SERVER_VAR="dnsserver"
GIT_STATUS_CMD="git status -s"
GFWLIST_CONF="03-gfwlist.conf"

# Run gfwlist2dnsmasq.sh
sh "$GFWLIST2DNSMASQ_SH" -l --extra-domain-file "$INCLUDE_LIST_TXT" --exclude-domain-file "$EXCLUDE_LIST_TXT" -o "$TMP"

# Edit tmp using sed
sed -i "
    s/$/ } on-error={}/g
    s/^/:do { add forward-to=$DNS_SERVER type=FWD address-list=$GFW_LIST match-subdomain=yes name=/g
    1s/^/\/ip dns static\n/
    1s/^/\/ip dns static remove [\/ip dns static find forward-to=$DNS_SERVER ]\n/
    1s/^/:global $DNS_SERVER_VAR\n/
" "$TMP"

sed -i -e '$a\/ip dns cache flush' "$TMP"

# Move tmp to gfwlist_v7.rsc
mv "$TMP" "$GFWLIST_V7_RSC"

# Check if git has any changes
if [ $(${GIT_STATUS_CMD} | wc -l) = 1 ]
then
    # If there's one change, checkout 03-gfwlist.conf
    git checkout "$GFWLIST_CONF"
fi
