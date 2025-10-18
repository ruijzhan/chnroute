# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`chnroute` is an automated toolset that provides China mainland IP address lists and specific domain lists for RouterOS routers. The project uses GitHub Actions for daily automatic updates to ensure users always have the latest network routing rules.

## Development Commands

### Building and Generation
- `make` - Main command that executes the generation process (runs `generate.sh`)
- `bash generate.sh` - Main generation script that downloads latest data and creates all configuration files
- `bash generate_cn.sh` - Optional script for generating China domain list (legacy)

### Dependencies
The scripts require these standard Unix tools:
- bash
- curl or wget
- awk
- sort
- base64

Most Linux distributions include these by default.

## Architecture

### Core Components

**Main Generation Pipeline (`generate.sh`)**:
- Orchestrates the entire generation process in 5 steps
- Downloads China IP list from iwik.org and GFW list from GitHub
- Processes domain lists with exclude/include functionality
- Generates RouterOS scripts in both standard and memory-optimized versions
- Handles error recovery, logging, and cleanup

**GFW List Converter (`gfwlist2dnsmasq.sh`)**:
- Converts base64-encoded GFW list to domain lists or dnsmasq rules
- Supports multiple output formats (domain lists, dnsmasq rules with/without ipset)
- Includes comprehensive Google and Blogspot domain lists
- Handles exclude/include domain files for customization

### Data Flow

1. **Download Phase**: Parallel downloads of CN.rsc (IP addresses) and GFW list (domains)
2. **Processing Phase**: Base64 decode GFW list, extract domains, apply custom filters
3. **Generation Phase**: Create RouterOS scripts in multiple formats
4. **Output Phase**: Generate final .rsc files and domain lists

### Generated Files

**RouterOS Scripts**:
- `CN.rsc` - China IPv4 address list (permanent timeout)
- `CN_mem.rsc` - Memory-optimized version (248-day timeout, reduces disk I/O)
- `LAN.rsc` - Private network IP ranges
- `gfwlist.rsc` - GFW domain rules for RouterOS v6 and earlier
- `gfwlist_v7.rsc` - Optimized version for RouterOS v7.6+ (uses Match Subdomains)

**Other Formats**:
- `03-gfwlist.conf` - dnsmasq format rules (compatible with OpenWrt)
- `gfwlist.txt` - Plain text domain list

### Configuration Files

**Domain Customization**:
- `include_list.txt` - Additional domains to add to GFW list
- `exclude_list.txt` - Domains to remove from GFW list

Both files use plain text format, one domain per line.

## Key Features

### Performance Optimizations
- Parallel downloads for faster execution
- Memory-optimized scripts to reduce disk I/O on RouterOS devices
- Batch processing of domains and IP addresses
- Efficient grep/awk pipelines for data processing

### Error Handling
- Comprehensive retry logic for network downloads
- Graceful degradation when optional components fail
- Detailed logging with timestamps and color coding
- Automatic cleanup of temporary files

### RouterOS Compatibility
- Support for both legacy and v7+ RouterOS versions
- Variable DNS server configuration via `$dnsserver` global variable
- Address list management with configurable timeouts
- DNS cache flushing and logging integration

## Automation

The project uses GitHub Actions for automatic updates:
- **Schedule**: Daily at 21:00 UTC (5:00 AM Beijing time next day)
- **Trigger**: Also runs on pushes to master branch (excluding docs)
- **Process**: Runs `make`, commits changes if any files are updated
- **Cache**: Uses GitHub Actions cache for improved performance

## Integration Examples

### RouterOS Import Scripts
The project generates ready-to-use RouterOS scripts that can be imported via:
```ros
/tool fetch url=https://raw.githubusercontent.com/ruijzhan/chnroute/master/CN.rsc
/import file-name=CN.rsc
```

### DNS Configuration
Users can configure custom DNS servers globally:
```ros
:global dnsserver 8.8.8.8
```

The generated scripts automatically use this global variable for DNS forwarding.