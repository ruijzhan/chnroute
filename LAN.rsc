/log info "Loading LAN ipv4 address list"
/ip firewall address-list remove [/ip firewall address-list find list=LAN]
/ip firewall address-list
:do { add list=LAN address=0.0.0.0/8 } on-error={}
:do { add list=LAN address=10.0.0.0/8 } on-error={} 
:do { add list=LAN address=100.64.0.0/10 } on-error={} 
:do { add list=LAN address=127.0.0.0/8 } on-error={} 
:do { add list=LAN address=169.254.0.0/16 } on-error={} 
:do { add list=LAN address=172.16.0.0/12 } on-error={} 
:do { add list=LAN address=192.0.0.0/24 } on-error={} 
:do { add list=LAN address=192.0.2.0/24 } on-error={} 
:do { add list=LAN address=192.168.0.0/16 } on-error={} 
:do { add list=LAN address=192.88.99.0/24 } on-error={} 
:do { add list=LAN address=198.18.0.0/15 } on-error={} 
:do { add list=LAN address=198.51.100.0/24 } on-error={} 
:do { add list=LAN address=203.0.113.0/24 } on-error={} 
:do { add list=LAN address=224.0.0.0/4 } on-error={} 
:do { add list=LAN address=240.0.0.0/4 } on-error={} 
