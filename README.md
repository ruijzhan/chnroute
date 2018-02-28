# chnroute
A continuesly updated list of IPs within China and address list adding script to RouterOS

By commands:

# curl 'http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest' | grep ipv4 | grep CN | awk -F\| '{ printf("%s/%d\n", $4, 32-log($5)/log(2)) }' > chnroute.txt
# sed 's/^/\/ip firewall address-list add list=CN address=/' chnroute.txt > chnroute_ros.txt
