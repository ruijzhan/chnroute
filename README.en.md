# chnroute

[![built with Codeium](https://codeium.com/badges/main)](https://codeium.com) [![Daily Make and Commit](https://github.com/ruijzhan/chnroute/actions/workflows/main.yaml/badge.svg)](https://github.com/ruijzhan/chnroute/actions/workflows/main.yaml)

## Automatically Updated China IP Address and Specific Domain Lists

This project provides continuously updated lists of China IP addresses and specific domains, and generates configuration scripts for RouterOS routers.

### 1. Rule Updates

- **China IP Ranges**: Sourced from [this website](http://www.iwik.org/ipcountry/mikrotik/CN).
- **Specific Domains**: Maintained by the [gfwlist project](https://github.com/gfwlist/gfwlist).

You can update the lists and generate RouterOS rule scripts with the following command:

```shell
# Update lists and generate RouterOS rule scripts
make
```

Generated files include:

- **[CN.rsc](./CN.rsc)**: IPv4 address ranges for mainland China, allocated by [IANA](https://www.iana.org/).
- **[LAN.rsc](./LAN.rsc)**: Internal network IPv4 address ranges.
- **[gfwlist.rsc](./gfwlist.rsc)**: RouterOS script generated from gfwlist, containing specific domains.
- **[gfwlist_v7.rsc](./gfwlist_v7.rsc)**: gfwlist script for RouterOS v7.6 and above.

Before generating rules, you can manually exclude or include specific domains by modifying `exclude_list.txt` and `include_list.txt`.

### 2. Importing and Applying China IP Ranges

Importing China IP ranges helps configure traffic splitting. In network access optimization scenarios, you can mark traffic with destination IPs not belonging to CN or LAN lists to route through optimized network paths.

#### 2.1 Importing China IP Ranges to RouterOS

Use the following script to import CN and LAN IP ranges into RouterOS:

```ros
/system script
add dont-require-permissions=no name=cn owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
/tool fetch url=https://raw.githubusercontent.com/ruijzhan/chnroute/master/CN.rsc
import file-name=CN.rsc
file remove CN.rsc

/tool fetch url=https://raw.githubusercontent.com/ruijzhan/chnroute/master/LAN.rsc
import file-name=LAN.rsc
file remove LAN.rsc"
```

#### 2.2 Network Optimization Rule Configuration

In the `PREROUTING` chain, redirect traffic with destinations not in CN to a custom chain, and configure the following rules in the custom chain:

1. Match traffic with destinations in LAN, directly `RETURN`.
2. Mark routing for remaining traffic based on connection protocol and destination port.
3. In the routing table, direct this traffic to the optimized network gateway.

### 3. Optimizing DNS Resolution with gfwlist

[gfwlist](https://github.com/gfwlist/gfwlist) provides a list of specific domains. Combined with RouterOS's regex matching capabilities, you can set different DNS servers for specific domains to optimize resolution speed.

#### 3.1 Configuring Unrestricted DNS Servers

Set a global variable `dnsserver` in RouterOS to specify an unrestricted DNS server (e.g., 8.8.8.8). The following script will reset the DNS server on each system startup:

```ros
/system scheduler
add name=envs on-event="{\r\
    \n  :global dnsserver 8.8.8.8;\r\
    \n}" policy=read,write,policy,test start-time=startup
```

Use the following command to view environment variables:

```shell
[admin@RouterBoard] > /system/script/environment/print 
Columns: NAME, VALUE
#  NAME       VALUE       
0  dnsserver  8.8.8.8
```

#### 3.2 Importing gfwlist to RouterOS

Use the following command to import the gfwlist into RouterOS:

```ros
/system script
add dont-require-permissions=no name=gfwlist owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
/tool fetch url=https://raw.githubusercontent.com/ruijzhan/chnroute/master/gfwlist.rsc
/import file-name=gfwlist.rsc
/file remove gfwlist.rsc
:log warning \"gfwlist domains imported successfully\""
```

**Note**: RouterOS v7.6 added the `Match Subdomains` option. You can import [gfwlist_v7.rsc](./gfwlist_v7.rsc) to improve resolution performance.

**Note**: Several thousand DNS rules may exceed the default 2M cache size. You need to set the DNS cache size to 20560KiB or larger:

```ros
/ip/dns/set cache-size=20560KiB
```

Use the following command to view imported DNS resolution rules:

```ros
/ip/dns/static/print
```

Example DNS settings after configuration:

```shell
[admin@RouterBoard] > /ip/dns/print 
                      servers: 223.5.5.5,223.6.6.6
              dynamic-servers: 
               use-doh-server: 
              verify-doh-cert: no
        allow-remote-requests: yes
          max-udp-packet-size: 4096
         query-server-timeout: 2s
          query-total-timeout: 10s
       max-concurrent-queries: 100
  max-concurrent-tcp-sessions: 20
                   cache-size: 20560KiB
                cache-max-ttl: 1w
                   cache-used: 16957KiB
```

All domain resolution requests matching the rules will be handled by the specified unrestricted DNS server (e.g., 8.8.8.8), while other domains will still be resolved by domestic DNS servers.

If results from 8.8.8.8 still have issues in China, you can redirect traffic destined for 8.8.8.8 to another DNS server using the following `dst-nat` rule:

```ros
/ip/firewall/nat
add action=dst-nat chain=output comment=BuyVM dst-address=8.8.8.8 to-addresses=192.168.9.1
```
