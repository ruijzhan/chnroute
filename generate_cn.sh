#!/bin/bash

wget https://raw.githubusercontent.com/felixonmars/dnsmasq-china-list/master/accelerated-domains.china.conf -O tmp1
cat tmp1 | cut -d '/' -f2 > tmp
cp tmp cnlist.txt
sed -i 's/\./\\\\./g' tmp
sed -i 's/$/\\$" } on-error={}/g' tmp
sed -i 's/^/:do { add forward-to=$alidns type=FWD regexp=".*/g' tmp
sed -i '1s/^/\/ip dns static\n/' tmp
sed -i '1s/^/\/ip dns static remove [\/ip dns static find forward-to=$alidns ]\n/' tmp
sed -i '1s/^/:global alidns\n/' tmp
sed -i -e '$a\/ip dns cache flush' tmp
mv tmp cnlist.rsc
rm tmp1