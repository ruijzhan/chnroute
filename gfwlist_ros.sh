#!/bin/bash

sh gfwlist2dnsmasq.sh -l -o tmp
sed -i 's/\./\\\\./g' tmp
sed -i 's/$/\\$"/g' tmp
sed -i 's/^/\/ip dns static add forward-to=192.168.9.1 type=FWD regexp=".*/g' tmp
sed -i '1s/^/\/ip dns static remove [\/ip dns static find type=FWD ]\n/' tmp
sed -i -e '$a\/ip dns cache flush' tmp
mv tmp gfwlist_ros.rsc