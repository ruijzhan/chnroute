#!/usr/bin/env bash

set -euo pipefail

export LC_ALL=POSIX

# Constants
readonly URL="https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/accelerated-domains.china.conf"
readonly OUTPUT_RSC="cnlist.rsc"
readonly TMP_FILE="$(mktemp)"

cleanup() {
    rm -f "$TMP_FILE"
}

trap cleanup EXIT

# Download the file and check if successful
if wget "$URL" -O - | cut -d '/' -f2 > "$TMP_FILE"; then
    # Process the file and generate cnlist.rsc
    sed -e '
        s/\./\\\\./g;
        s/$/\\$" } on-error={}/g;
        s/^/:do { add forward-to=$alidns type=FWD regexp="/g;
        1s/^/\/ip dns static\n/;
        1s/^/\/ip dns static remove [\/ip dns static find forward-to=$alidns ]\n/;
        1s/^/:global alidns\n/;
        $a\/ip dns cache flush
        ' "$TMP_FILE" > "$OUTPUT_RSC"
else
    echo "Error downloading file." >&2
    exit 1
fi
