# chnroute

[![built with Codeium](https://codeium.com/badges/main)](https://codeium.com) [![Daily Make and Commit](https://github.com/ruijzhan/chnroute/actions/workflows/main.yaml/badge.svg)](https://github.com/ruijzhan/chnroute/actions/workflows/main.yaml)

## Project Overview

`chnroute` is an automatically updating toolkit that provides China mainland IP address lists and specific domain lists, generating ready-to-use configuration scripts for RouterOS routers. This project implements daily automatic updates through GitHub Actions, ensuring you always have the latest network rules.

### Key Features

- **Auto-updated China IP Address Lists**: For smart routing and traffic splitting
- **Specific Domain Lists**: Based on gfwlist, for optimizing DNS resolution
- **RouterOS Configuration Scripts**: Ready-to-use scripts, easily imported into MikroTik devices

## 1. Data Sources and File Descriptions

### 1.1 Data Sources

- **China IP Ranges**: From [iwik.org](http://www.iwik.org/ipcountry/mikrotik/CN), allocated to mainland China by [IANA](https://www.iana.org/)
- **Specific Domain Lists**: Maintained by the [gfwlist project](https://github.com/gfwlist/gfwlist)

### 1.2 Generated Files

| Filename | Description |
|--------|------|
| [CN.rsc](./CN.rsc) | Mainland China IPv4 address ranges, RouterOS format |
| [CN_mem.rsc](./CN_mem.rsc) | Memory-optimized version of China IP address list |
| [LAN.rsc](./LAN.rsc) | Internal network IPv4 address ranges |
| [gfwlist.rsc](./gfwlist.rsc) | RouterOS DNS rule script generated from gfwlist |
| [gfwlist_v7.rsc](./gfwlist_v7.rsc) | Optimized script for RouterOS v7.6+ (using Match Subdomains feature) |

### 1.3 Custom Lists

You can customize domain lists by modifying the following files:
- `exclude_list.txt`: Domains to exclude from gfwlist
- `include_list.txt`: Additional domains to include

## 2. Usage Instructions

### 2.1 Manual Rule Updates

After cloning the repository, run the following command to update all lists and generate RouterOS rule scripts:

```shell
make
```

### 2.2 Importing and Applying China IP Ranges

#### 2.2.1 Importing China IP Ranges to RouterOS

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

#### 2.2.2 Configuring Traffic Splitting Rules

In RouterOS, you can set up the following rules to optimize network access:

1. In the `PREROUTING` chain, redirect traffic with destinations not in CN to a custom chain
2. In the custom chain:
   - Match traffic with destinations in LAN, directly `RETURN`
   - Mark routing for other traffic based on connection protocol and destination port
   - In the routing table, direct marked traffic to the optimized network gateway

This configuration enables smart routing where domestic traffic connects directly, while international traffic is routed through optimized paths.

### 2.3 Optimizing DNS Resolution with gfwlist

#### 2.3.1 Configuring Global DNS Variables

Set a global variable `dnsserver` in RouterOS to specify an alternative DNS server:

```ros
/system scheduler
add name=envs on-event="{\r\
    \n  :global dnsserver 8.8.8.8;\r\
    \n}" policy=read,write,policy,test start-time=startup
```

View environment variables:

```shell
[admin@RouterBoard] > /system/script/environment/print 
Columns: NAME, VALUE
#  NAME       VALUE       
0  dnsserver  8.8.8.8
```

#### 2.3.2 Importing gfwlist to RouterOS

Use the following script to import gfwlist rules:

```ros
/system script
add dont-require-permissions=no name=gfwlist owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
/tool fetch url=https://raw.githubusercontent.com/ruijzhan/chnroute/master/gfwlist.rsc
/import file-name=gfwlist.rsc
/file remove gfwlist.rsc
:log warning \"gfwlist domains imported successfully\""
```

> **Tip**: RouterOS v7.6+ users can import [gfwlist_v7.rsc](./gfwlist_v7.rsc) for better performance

#### 2.3.3 Increasing DNS Cache Size

Due to the large number of rules, you need to increase the DNS cache size:

```ros
/ip/dns/set cache-size=20560KiB
```

After configuration, you can view DNS settings:

```ros
/ip/dns/static/print
```

#### 2.3.4 DNS Request Redirection (Optional)

If you need to redirect DNS requests to another server:

```ros
/ip/firewall/nat
add action=dst-nat chain=output comment=CustomDNS dst-address=8.8.8.8 to-addresses=192.168.9.1
```

## 3. Automatic Update Mechanism

This project implements daily automatic updates through GitHub Actions:

- Automatically runs update scripts daily at 21:00 UTC (05:00 Beijing time the next day)
- Automatically commits updated rule files to the repository
- You can fetch the latest rules from GitHub using scheduled tasks

## 4. Contributions and Feedback

Contributions and feedback are welcome through [Issues](https://github.com/ruijzhan/chnroute/issues) or [Pull Requests](https://github.com/ruijzhan/chnroute/pulls).

---

[中文版](./README.md)
