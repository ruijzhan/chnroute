#!/bin/bash

set -euo pipefail  # Enable error handling and logging

# Define constants
GFWLIST2DNSMASQ_SH="gfwlist2dnsmasq.sh"
INCLUDE_LIST_TXT="include_list.txt"
EXCLUDE_LIST_TXT="exclude_list.txt"
TMP="tmp"
TMP_BACKUP="tmp_backup"
GFW_LIST="gfw_list"
DNS_SERVER="\$dnsserver"
DNS_SERVER_VAR="dnsserver"
GFWLIST_RSC="gfwlist.rsc"
CN_RSC="CN.rsc"
GFWLIST_V7_RSC="gfwlist_v7.rsc"
GIT_STATUS_CMD="git status -s"
GFWLIST_CONF="03-gfwlist.conf"
CN_URL="http://www.iwik.org/ipcountry/mikrotik/CN"

# Run gfwlist2dnsmasq.sh and generate gfwlist.rsc
sh "$GFWLIST2DNSMASQ_SH" -l \
    --extra-domain-file "$INCLUDE_LIST_TXT" \
    --exclude-domain-file "$EXCLUDE_LIST_TXT" \
    -o "$TMP"

cp "$TMP" "$TMP_BACKUP"

# Edit tmp using sed
sed -i "
    s/\./\\\\\\\\./g;
    s/$/\\\\$\" } on-error={}/g;
    s/^/:do { add forward-to=${DNS_SERVER} type=FWD address-list=${GFW_LIST} regexp=\".*/g;
    1s/^/\/ip dns static\n/;
    1s/^/\/ip dns static remove [\/ip dns static find forward-to=${DNS_SERVER} ]\n/;
    1s/^/:global ${DNS_SERVER_VAR}\n/
    " "$TMP"
sed -i -e '$a\/ip dns cache flush' "$TMP"

# Remove existing gfwlist.rsc if any and move tmp to gfwlist.rsc
# rm -f "$GFWLIST_RSC"
mv -f "$TMP" "$GFWLIST_RSC"

mv "$TMP_BACKUP" "$TMP"

# Edit tmp using sed
sed -i "
    s/$/ } on-error={}/g;
    s/^/:do { add forward-to=${DNS_SERVER} type=FWD address-list=${GFW_LIST} match-subdomain=yes name=/g;
    1s/^/\/ip dns static\n/;
    1s/^/\/ip dns static remove [\/ip dns static find forward-to=${DNS_SERVER} ]\n/;
    1s/^/:global ${DNS_SERVER_VAR}\n/
    " "$TMP"
sed -i -e '$a\/ip dns cache flush' "$TMP"

# Move tmp to gfwlist_v7.rsc
mv -f "$TMP" "$GFWLIST_V7_RSC"

# Check if git has any changes
if [ $(${GIT_STATUS_CMD} | wc -l) -eq 1 ]; then
    # If there's one change, checkout 03-gfwlist.conf
    git checkout "$GFWLIST_CONF"
fi

# Download the CN.rsc file from http://www.iwik.org/ipcountry/mikrotik/CN,
# saving it as $CN_RSC. If the download fails, print an error message to stderr.
if ! wget "$CN_URL" -O "$CN_RSC" >/dev/null 2>&1; then
    printf 'Error: failed to download %s\n' "$CN_RSC" >&2
fi
