#!/bin/bash

sh gfwlist2dnsmasq.sh -l --extra-domain-file include_list.txt --exclude-domain-file exclude_list.txt -o tmp
# sed -i 's/\./\\\\./g' tmp
sed -i 's/$/ } on-error={}/g' tmp
sed -i 's/^/:do { add forward-to=$dnsserver type=FWD address-list=gfw_list match-subdomain=yes name=/g' tmp
sed -i '1s/^/\/ip dns static\n/' tmp
sed -i '1s/^/\/ip dns static remove [\/ip dns static find forward-to=$dnsserver ]\n/' tmp
sed -i '1s/^/:global dnsserver\n/' tmp
sed -i -e '$a\/ip dns cache flush' tmp
mv tmp gfwlist_v7.rsc
