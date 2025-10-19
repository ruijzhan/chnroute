# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`chnroute` is an automated toolset that provides China mainland IP address lists and specific domain lists for RouterOS routers. The project uses GitHub Actions for daily automatic updates to ensure users always have the latest network routing rules.

## Development Commands

### Building and Generation
- `make` or `make generate` - Main command that executes the generation process (runs `generate.sh`)
- `make fast` - Run generation without dependency checks (faster for development)
- `bash generate.sh` - Main generation script that downloads latest data and creates all configuration files
- `bash gfwlist2dnsmasq.sh` - GFW list converter (called automatically by main script)

### Testing and Validation
- `make test` - Run generation and validate output files
- `make check` - Verify dependencies and shell script syntax
- `make validate` or `make validate-output` - Validate generated output files exist and are non-empty
- `make ci-test` - Run comprehensive local CI workflow (clean, check, test, benchmark, analyze)

### Development Tools
- `make benchmark` - Measure generation performance with timing analysis
- `make analyze` - Summarize output file sizes and line counts
- `make memory-profile` - Gather memory usage information during generation
- `make dev-setup` - Create development aliases and shell completion
- `make clean` - Remove temporary files and artifacts

### System Installation (requires root)
- `sudo make install` - Install scripts and data to `/opt/chnroute`
- `sudo make service-setup` - Configure systemd timer for daily updates
- `sudo make uninstall` - Remove installed files and services
- `make package` - Create distributable archive under `dist/`

### Dependencies
The scripts require these standard Unix tools:
- **Core**: bash, curl or wget, awk, sort, base64, grep, sed, tar
- **Optional**: shellcheck (for static analysis), python3 (for benchmark averages), /usr/bin/time (for detailed timing)

Most Linux distributions include these by default.

## Architecture

### Core Components

**Main Generation Pipeline (`generate.sh`)**:
- Modular script using lib/ directory for separation of concerns
- Downloads China IP list from iwik.org and GFW list from GitHub in parallel
- Processes domain lists with exclude/include functionality
- Generates RouterOS scripts in both standard and memory-optimized versions
- Handles error recovery, logging, and cleanup through dedicated modules

**GFW List Converter (`gfwlist2dnsmasq.sh`)**:
- Converts base64-encoded GFW list to domain lists or dnsmasq rules
- Supports multiple output formats (domain lists, dnsmasq rules with/without ipset)
- Includes comprehensive Google and Blogspot domain lists
- Handles exclude/include domain files for customization

**Library Modules (`lib/`)**:
- `config.sh` - Central configuration, constants, and metadata
- `logger.sh` - Logging utilities with color output and levels
- `downloader.sh` - Network downloads with retry logic and error handling
- `processor.sh` - Parallel data processing and domain formatting
- `validation.sh` - Input validation and file existence checking
- `error.sh` - Error handling utilities and cleanup functions
- `temp.sh` - Temporary file management and cleanup
- `platform.sh` - Platform detection and compatibility
- `dependencies.sh` - Dependency checking and validation
- `resources.sh` - External resource URLs and data sources

### Data Flow

1. **Setup Phase**: Initialize logging, temp directory, and validate dependencies
2. **Download Phase**: Parallel downloads of CN.rsc (IP addresses) and GFW list (domains) using retry logic
3. **Processing Phase**: Base64 decode GFW list, extract domains, apply custom include/exclude filters
4. **Generation Phase**: Create RouterOS scripts in multiple formats with parallel processing
5. **Output Phase**: Generate final .rsc files and domain lists with validation
6. **Cleanup Phase**: Remove temporary files and artifacts

### Performance Optimizations

- **Parallel Processing**: Multi-threaded domain processing using configurable thread count
- **Retry Logic**: Exponential backoff for network downloads with configurable timeouts
- **Memory Efficiency**: Streaming processing for large files to minimize memory usage
- **Batch Operations**: Efficient awk/sed pipelines for data transformation
- **Caching**: Intelligent file caching to avoid redundant downloads

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