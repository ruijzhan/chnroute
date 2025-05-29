# chnroute

[![built with Codeium](https://codeium.com/badges/main)](https://codeium.com) [![Daily Make and Commit](https://github.com/ruijzhan/chnroute/actions/workflows/main.yaml/badge.svg)](https://github.com/ruijzhan/chnroute/actions/workflows/main.yaml)

## Project Overview

`chnroute` is an automatically updating toolkit that provides China mainland IP address lists and specific domain lists, generating ready-to-use configuration scripts for RouterOS routers. This project implements daily automatic updates through GitHub Actions, ensuring you always have the latest network rules.

### Key Features

- **Auto-updated China IP Address Lists**: For smart routing and traffic splitting
- **Specific Domain Lists**: Based on gfwlist, for optimizing DNS resolution
- **RouterOS Configuration Scripts**: Ready-to-use scripts, easily imported into MikroTik devices
- **Memory-optimized Version**: Optimized scripts for resource-constrained devices

## 1. Data Sources and File Descriptions

### 1.1 Data Sources

- **China IP Ranges**: From [iwik.org](http://www.iwik.org/ipcountry/mikrotik/CN), allocated to mainland China by [IANA](https://www.iana.org/)
- **Specific Domain Lists**: Maintained by the [gfwlist project](https://github.com/gfwlist/gfwlist)
- **Update Frequency**: Data sources are updated daily, synchronized automatically through GitHub Actions

### 1.2 Generated Files

| Filename | Description |
|--------|------|
| [CN.rsc](./CN.rsc) | Mainland China IPv4 address ranges, RouterOS format |
| [CN_mem.rsc](./CN_mem.rsc) | Memory-optimized version of China IP address list, avoiding disk I/O |
| [LAN.rsc](./LAN.rsc) | Internal network IPv4 address ranges |
| [gfwlist.rsc](./gfwlist.rsc) | RouterOS DNS rule script generated from gfwlist |
| [gfwlist_v7.rsc](./gfwlist_v7.rsc) | Optimized script for RouterOS v7.6+ (using Match Subdomains feature) |
| [03-gfwlist.conf](./03-gfwlist.conf) | dnsmasq format gfwlist rules (usable with OpenWrt and similar systems) |
| [gfwlist.txt](./gfwlist.txt) | Processed plain text domain list |

### 1.3 Custom Lists

You can customize domain lists by modifying the following files:
- `exclude_list.txt`: Domains to exclude from gfwlist
- `include_list.txt`: Additional domains to include

These files use plain text format with one domain per line. After modification, you need to run the generation script to update the rule files.

## 2. Usage Instructions

### 2.1 Manual Rule Updates

After cloning the repository, run the following command to update all lists and generate RouterOS rule scripts:

```shell
make
```

This will execute the `generate.sh` script, download the latest IP lists and domain lists, and generate all configuration files.

#### 2.1.1 Dependencies

The script requires the following dependencies:
- bash
- curl or wget
- awk
- sort
- base64

Most Linux distributions have these tools installed by default.

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

### 3.1 RouterOS Automatic Update Configuration

You can set up a scheduled task in RouterOS to automatically fetch the latest rules from GitHub:

```ros
/system scheduler
add interval=1d name=update_chnroute on-event="/system script run cn\r\n/system script run gfwlist\r\n/log info \"chnroute rules updated\"" policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon start-date=jan/01/1970 start-time=04:30:00
```

This configuration will automatically update the rules every day at 4:30 AM.

## 4. Project Structure

```
.
├── .github/workflows/  # GitHub Actions workflow configuration
├── CN.rsc             # Mainland China IPv4 address ranges RouterOS script
├── CN_mem.rsc         # Memory-optimized version of China IP address list
├── LAN.rsc            # Internal network IPv4 address ranges RouterOS script
├── Makefile           # Build script
├── README.md          # Chinese documentation
├── README.en.md       # English documentation
├── exclude_list.txt   # Excluded domains list
├── generate.sh        # Main generation script
├── generate_cn.sh     # China IP list generation script
├── gfwlist.txt        # Processed domain list
├── gfwlist2dnsmasq.sh # gfwlist conversion script
├── gfwlist_v7.rsc     # RouterOS v7+ version of gfwlist script
└── include_list.txt   # Included domains list
```

## 5. Troubleshooting

### 5.1 Common Issues

**Q: DNS resolution becomes slow after importing rules?**

A: Try increasing the DNS cache size or consider using the optimized script for RouterOS v7.6+.

**Q: Some websites are still inaccessible?**

A: Check your DNS server configuration, ensuring the `$dnsserver` variable points to a reliable DNS server. You can also add missing domains by modifying `include_list.txt`.

**Q: How to verify if rules are effective?**

A: Run the following command in RouterOS to see the loaded rules:
```ros
/ip dns static print count-only
```

## 6. Advanced Usage

### 6.1 Custom Scripts

You can modify the `generate.sh` script to customize the generation process, such as adding more IP list sources or adjusting domain processing logic.

### 6.2 Integration with Other Systems

Besides RouterOS, the rules generated by this project can also be used with other systems:

- **OpenWrt**: Use `03-gfwlist.conf` with dnsmasq
- **Other routing systems**: You can reference the script logic to convert rules to formats suitable for your system

## 7. Contributions and Feedback

Contributions and feedback are welcome through [Issues](https://github.com/ruijzhan/chnroute/issues) or [Pull Requests](https://github.com/ruijzhan/chnroute/pulls).

---

[中文版](./README.md)
