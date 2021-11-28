#!/bin/bash

sh gfwlist2dnsmasq.sh -l --extra-domain-file my_gfwlist.txt -o tmp
cp tmp gfwlist.txt
sed -i 's/\./\\\\./g' tmp
sed -i 's/$/\\$"/g' tmp
sed -i 's/^/\/ip dns static add forward-to=$dnsserver type=FWD regexp=".*/g' tmp
sed -i '1s/^/\/ip dns static remove [\/ip dns static find type=FWD ]\n/' tmp
sed -i '1s/^/:global dnsserver\n/' tmp
sed -i -e '$a\/ip dns cache flush' tmp
mv tmp gfwlist.rsc
wget http://www.iwik.org/ipcountry/mikrotik/CN -O CN.rsc
