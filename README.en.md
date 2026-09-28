# chnroute

[![built with Codeium](https://codeium.com/badges/main)](https://codeium.com) [![Daily Make and Commit](https://github.com/ruijzhan/chnroute/actions/workflows/main.yaml/badge.svg)](https://github.com/ruijzhan/chnroute/actions/workflows/main.yaml)

[中文版](./README.md) · [Makefile User Guide](./MAKEFILE_USER_GUIDE.md)

## Project Overview

`chnroute` is an automatically updating network rules toolkit: it fetches China mainland IP ranges and the [gfwlist](https://github.com/gfwlist/gfwlist) domain list daily, generates ready-to-import configuration scripts for MikroTik RouterOS, and also provides generic formats such as a plain-text domain list. Rules are regenerated and committed automatically every day via GitHub Actions — no manual maintenance required.

### Key Features

- **China IP address lists**: ~8,100 IPv4 ranges for smart routing and traffic splitting
- **gfwlist domain rules**: ~4,300 domains, generated as RouterOS DNS static rules and a plain domain list
- **Ready-to-use RouterOS scripts**: one-click import, safe to re-run
- **Customizable and extensible**: add/remove domains via include/exclude lists; generation logic modularized in `lib/`

## Table of Contents

- [1. Generated Files](#1-generated-files)
- [2. Quick Start](#2-quick-start)
- [3. RouterOS Configuration Guide](#3-routeros-configuration-guide)
- [4. Automatic Updates](#4-automatic-updates)
- [5. Local Development and Testing](#5-local-development-and-testing)
- [6. Troubleshooting](#6-troubleshooting)
- [7. Contributions and Feedback](#7-contributions-and-feedback)

## 1. Generated Files

### 1.1 File List

| File | Description | Status |
|------|-------------|--------|
| [CN.rsc](./CN.rsc) | Mainland China IPv4 ranges, imported into the RouterOS `CN` address list with permanent entries | Generated daily |
| [CN_mem.rsc](./CN_mem.rsc) | Memory-optimized variant of the CN list, entries expire automatically after 248 days | Generated daily |
| [gfwlist_v7.rsc](./gfwlist_v7.rsc) | RouterOS v7.6+ DNS static rules from gfwlist domains | Generated daily |
| [gfwlist.txt](./gfwlist.txt) | Plain-text domain list, one domain per line, usable on any system | Generated daily |
| [LAN.rsc](./LAN.rsc) | Private and reserved network ranges, imported into the RouterOS `LAN` address list | Statically maintained |
| [03-gfwlist.conf](./03-gfwlist.conf) | dnsmasq format rules (OpenWrt etc.) | Legacy, no longer regenerated |

> **Tip**: OpenWrt users should not rely on the legacy file above — see [5.3 Integration with Other Systems](#53-integration-with-other-systems) to generate fresh rules yourself.

### 1.2 Data Sources

- **China IP ranges**: from [iwik.org](http://www.iwik.org/ipcountry/mikrotik/CN), allocated to mainland China by [IANA](https://www.iana.org/)
- **Domain list**: maintained by the [gfwlist project](https://github.com/gfwlist/gfwlist)
- **Update frequency**: GitHub Actions regenerates and commits daily at 21:00 UTC (05:00 Beijing time the next day)

### 1.3 Custom Domain Lists

Customize the domain list via two plain-text files (one domain per line):

- `include_list.txt`: additional domains to include
- `exclude_list.txt`: domains to exclude from gfwlist

Re-run the generation script after modifying them — see [Local Development and Testing](#5-local-development-and-testing).

## 2. Quick Start

### 2.1 RouterOS Users

No need to clone the repository — RouterOS scripts can fetch the rule files directly from GitHub. See [3. RouterOS Configuration Guide](#3-routeros-configuration-guide).

### 2.2 Local Generation

```shell
git clone https://github.com/ruijzhan/chnroute.git
cd chnroute
make
```

This checks dependencies, downloads the latest IP and domain lists, and generates all rule files.

**Dependencies**: bash, curl, awk, sort, grep, base64, mktemp, wc. Most Linux distributions ship these by default; run `make check` to verify.

> For proxy access, set the standard `http_proxy` / `https_proxy` environment variables (supported natively by curl).

## 3. RouterOS Configuration Guide

### 3.1 Importing China IP Ranges

The following script imports the CN and LAN ranges into RouterOS:

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

The script clears the old `CN` list before importing, so it is safe to re-run.

### 3.2 Configuring Traffic Splitting Rules

In RouterOS, you can set up the following rules for smart routing:

1. In the `PREROUTING` chain, jump traffic whose destination is not in CN to a custom chain
2. In the custom chain:
   - Match traffic whose destination is in LAN and `RETURN` directly
   - Mark routing for other traffic based on connection protocol and destination port
   - Point the marked traffic to the optimized network gateway in the routing table

This enables smart routing where domestic traffic connects directly while international traffic goes through optimized paths.

### 3.3 Optimizing DNS Resolution with gfwlist

#### 3.3.1 Configuring the Global DNS Variable

The gfwlist rules use the global variable `$dnsserver` as the alternative DNS server. Set it first:

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

#### 3.3.2 Importing gfwlist Rules

> **Note**: `gfwlist_v7.rsc` requires RouterOS **v7.6 or newer** (it uses `type=FWD` static entries and the Match Subdomains feature).

```ros
/system script
add dont-require-permissions=no name=gfwlist owner=admin policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon source="
/tool fetch url=https://raw.githubusercontent.com/ruijzhan/chnroute/master/gfwlist_v7.rsc
/import file-name=gfwlist_v7.rsc
/file remove gfwlist_v7.rsc
:log warning \"gfwlist domains imported successfully\""
```

Script characteristics:

- Removes existing `forward-to=$dnsserver` entries before importing, safe to re-run
- Every domain enables `match-subdomain=yes`, automatically covering all its subdomains
- Resolved results are added to the `gfw_list` address list, which can be matched by firewall rules

#### 3.3.3 Increasing DNS Cache Size

Due to the large number of rules, increase the DNS cache:

```ros
/ip/dns/set cache-size=20560KiB
```

After configuration, view the loaded DNS static rules:

```ros
/ip/dns/static/print
```

#### 3.3.4 DNS Request Redirection (Optional)

To redirect DNS requests to another server:

```ros
/ip/firewall/nat
add action=dst-nat chain=output comment=CustomDNS dst-address=8.8.8.8 to-addresses=192.168.9.1
```

## 4. Automatic Updates

### 4.1 GitHub Actions

- Runs `make` daily at 21:00 UTC (05:00 Beijing time the next day) to regenerate all rules
- Commits and pushes changes with the message `Automated update: <timestamp>`
- Can also be triggered manually from the Actions page (pushes to master trigger it as well)

### 4.2 RouterOS Scheduled Updates

Set up a scheduled task in RouterOS to fetch the latest rules from GitHub daily:

```ros
/system scheduler
add interval=1d name=update_chnroute on-event="/system script run cn\r\n/system script run gfwlist\r\n/log info \"chnroute rules updated\"" policy=ftp,reboot,read,write,policy,test,password,sniff,sensitive,romon start-date=jan/01/1970 start-time=06:00:00
```

> Setting `start-time` around 06:00 (Beijing time) is recommended so that GitHub Actions has already committed the day's rules (around 05:00).

## 5. Local Development and Testing

### 5.1 Common Make Targets

| Command | Description |
|---------|-------------|
| `make` / `make generate` | Check dependencies and generate all rule files |
| `make fast` | Generate without dependency checks (for development) |
| `make check` | Verify dependencies and script syntax |
| `make test` | Generate and validate output files |
| `make analyze` | Summarize output file sizes and line counts |
| `make benchmark` | Run generation performance benchmark |
| `make ci-test` | Full local CI flow (clean → check → test → benchmark → analyze) |
| `sudo make install` | Install to `/opt/chnroute` |
| `sudo make service-setup` | Provision a systemd timer for daily system updates |

See the [Makefile User Guide](./MAKEFILE_USER_GUIDE.md) for all targets, or run `make help`.

### 5.2 Running Tests

```shell
bash tests/run_tests.sh
```

Runs unit tests covering core processing logic such as domain extraction and merging.

### 5.3 Integration with Other Systems

Besides RouterOS, use `gfwlist2dnsmasq.sh` to generate rules for other systems:

```shell
# Generate dnsmasq rules (OpenWrt etc.)
bash gfwlist2dnsmasq.sh -d 127.0.0.1 -p 5353 -s gfwlist -o 03-gfwlist.conf

# Generate a plain domain list (with extra and excluded domains)
bash gfwlist2dnsmasq.sh -l -o gfwlist.txt \
    --extra-domain-file include_list.txt \
    --exclude-domain-file exclude_list.txt
```

Run `bash gfwlist2dnsmasq.sh -h` for all options.

### 5.4 Project Structure

```text
.
├── .github/workflows/   # GitHub Actions daily update workflow
├── lib/                 # Core modules of the generation pipeline
│   ├── config.sh        # Central configuration and constants
│   ├── logger.sh        # Colorized, leveled logging
│   ├── downloader.sh    # Downloads with retry and timeouts
│   ├── processor.sh     # Domain extraction / IP formatting (single pass)
│   └── ...              # Dependency checks, validation, error handling, etc.
├── tests/               # Unit tests
├── generate.sh          # Main generation script
├── gfwlist2dnsmasq.sh   # gfwlist converter (usable standalone)
├── generate_cn.sh       # Optional China domain list generator (legacy)
├── include_list.txt     # Additional domains
├── exclude_list.txt     # Excluded domains
├── Makefile             # Build, test, and install entry point
├── CN.rsc               # China IP ranges (generated daily)
├── CN_mem.rsc           # Memory-optimized China IP list (generated daily)
├── gfwlist_v7.rsc       # RouterOS v7.6+ DNS rules (generated daily)
├── gfwlist.txt          # Plain domain list (generated daily)
├── LAN.rsc              # Private network ranges (statically maintained)
└── 03-gfwlist.conf      # dnsmasq rules (legacy)
```

## 6. Troubleshooting

**Q: Errors when importing the gfwlist rules?**

A: `gfwlist_v7.rsc` requires RouterOS v7.6 or newer. Check your version with `/system/package/print`.

**Q: DNS resolution becomes slow after importing rules?**

A: Increase the DNS cache (`/ip/dns/set cache-size=20560KiB`) and make sure the device has enough free memory.

**Q: Some websites are still inaccessible?**

A: Check that `$dnsserver` points to a reliable DNS server. You can also add missing domains to `include_list.txt` and regenerate.

**Q: How to verify the rules are effective?**

A: Run the following command in RouterOS to count the loaded rules:

```ros
/ip dns static print count-only
```

**Q: Local generation fails?**

A: Run `make check` to verify dependencies. For network issues, try setting `http_proxy` / `https_proxy` and retry.

## 7. Contributions and Feedback

Contributions and feedback are welcome through [Issues](https://github.com/ruijzhan/chnroute/issues) or [Pull Requests](https://github.com/ruijzhan/chnroute/pulls).

---

[![Powered by DartNode](https://dartnode.com/branding/DN-Open-Source-sm.png)](https://dartnode.com "Powered by DartNode - Free VPS for Open Source")
