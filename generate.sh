#!/bin/bash

set -euo pipefail  # Enable error handling and logging

# Define constants
GFWLIST2DNSMASQ_SH="gfwlist2dnsmasq.sh"
INCLUDE_LIST_TXT="include_list.txt"
EXCLUDE_LIST_TXT="exclude_list.txt"
TMP="tmp"
GFW_LIST="gfw_list"
DNS_SERVER="\$dnsserver"
DNS_SERVER_VAR="dnsserver"
GFWLIST_RSC="gfwlist.rsc"
CN_RSC="CN.rsc"

# Run gfwlist2dnsmasq.sh and generate gfwlist.rsc
sh "$GFWLIST2DNSMASQ_SH" -l --extra-domain-file "$INCLUDE_LIST_TXT" --exclude-domain-file "$EXCLUDE_LIST_TXT" -o "$TMP"

# Edit tmp using sed
sed -i "
    s/\./\\\\\\\\./g
    s/$/\\\\$\" } on-error={}/g
    s/^/:do { add forward-to=$DNS_SERVER type=FWD address-list=$GFW_LIST regexp=\".*/g
    1s/^/\/ip dns static\n/
    1s/^/\/ip dns static remove [\/ip dns static find forward-to=$DNS_SERVER ]\n/
    1s/^/:global $DNS_SERVER_VAR\n/
" "$TMP"

sed -i -e '$a\/ip dns cache flush' "$TMP"

# Remove existing gfwlist.rsc if any and move tmp to gfwlist.rsc
rm -f "$GFWLIST_RSC"
mv "$TMP" "$GFWLIST_RSC"

# Download CN.rsc
wget http://www.iwik.org/ipcountry/mikrotik/CN -O "$CN_RSC"
