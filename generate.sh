#!/bin/bash

sh gfwlist2dnsmasq.sh -l --extra-domain-file include_list.txt --exclude-domain-file exclude_list.txt -o tmp
sh gfwlist2dnsmasq.sh  -d 8.8.8.8 -p 53 --extra-domain-file include_list.txt --exclude-domain-file exclude_list.txt -o 03-gfwlist.conf
cp tmp gfwlist.txt
sed -i 's/\./\\\\./g' tmp
sed -i 's/$/\\$" } on-error={}/g' tmp
sed -i 's/^/:do { add forward-to=$dnsserver type=FWD address-list=gfw_list regexp=".*/g' tmp
sed -i '1s/^/\/ip dns static\n/' tmp
sed -i '1s/^/\/ip dns static remove [\/ip dns static find forward-to=$dnsserver ]\n/' tmp
sed -i '1s/^/:global dnsserver\n/' tmp
sed -i -e '$a\/ip dns cache flush' tmp
mv tmp gfwlist.rsc
wget http://www.iwik.org/ipcountry/mikrotik/CN -O CN.rsc
