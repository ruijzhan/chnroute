#!/bin/bash

# Constants
URL="https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/accelerated-domains.china.conf"
OUTPUT_RSC="cnlist.rsc"

# Download the file and check if successful
if wget "$URL" -O - | cut -d '/' -f2 > "cnlist.txt"; then
    # Process the file and generate cnlist.rsc
    sed -i -e '
        s/\./\\\\./g;
        s/$/\\$" } on-error={}/g;
        s/^/:do { add forward-to=$alidns type=FWD regexp="/g;
        1s/^/\/ip dns static\n/;
        1s/^/\/ip dns static remove [\/ip dns static find forward-to=$alidns ]\n/;
        1s/^/:global alidns\n/;
        $a\/ip dns cache flush
        ' "cnlist.txt"

    mv "cnlist.txt" "$OUTPUT_RSC"
else
    echo "Error downloading file."
    exit 1
fi
