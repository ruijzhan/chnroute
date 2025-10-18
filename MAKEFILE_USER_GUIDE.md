# chnroute Makefile User Guide

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Command Reference](#command-reference)
  - [Basic Targets](#basic-targets)
  - [Development Targets](#development-targets)
  - [System Targets](#system-targets)
- [Usage Examples](#usage-examples)
- [Development Workflow](#development-workflow)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)
- [Contributing](#contributing)

---

## Overview

The chnroute Makefile provides a comprehensive build system for generating China network routing rules and domain lists. It offers a wide range of targets for development, testing, deployment, and system administration.

### Key Features

- **Automated Generation**: Build China IP routes and GFW domain lists
- **Dependency Management**: Automatic checking of required tools and dependencies
- **Performance Monitoring**: Built-in benchmarking and memory profiling
- **Development Tools**: Shell aliases, tab completion, and development environment setup
- **System Integration**: Full systemd service support for automated updates
- **Package Management**: Create distributable archives for deployment
- **Validation**: Comprehensive output validation and syntax checking

### Target Categories

1. **Basic Targets**: Core functionality for route generation
2. **Development Targets**: Tools for developers and power users
3. **System Targets**: Installation and system administration features

---

## Prerequisites

### Required Tools

The Makefile automatically checks for these mandatory dependencies:

- **bash** (4.0+) - Shell interpreter
- **curl** - Network downloads
- **awk** - Text processing
- **sort** - Data sorting
- **base64** - Base64 encoding/decoding
- **grep** - Pattern searching
- **sed** - Stream editing
- **tar** - Archive creation

### Optional Tools

These tools enhance functionality but are not strictly required:

- **shellcheck** - Static analysis for shell scripts
- **python3** - Advanced benchmarking calculations
- **/usr/bin/time** (GNU time) - Detailed timing and memory profiling
- **systemctl** - Systemd service management

### System Requirements

- **Operating System**: Linux (tested on Ubuntu, CentOS, Debian)
- **Memory**: Minimum 512MB RAM available
- **Disk Space**: Minimum 100MB free space
- **Network**: Internet connection for downloading source data
- **Permissions**: Root access for system installation targets

---

## Installation

### 1. Clone the Repository

```bash
git clone https://github.com/ruijzhan/chnroute.git
cd chnroute
```

### 2. Verify Dependencies

```bash
make check
```

This command will verify all required tools are available and report any missing dependencies.

### 3. Test Basic Functionality

```bash
make generate
```

This will generate the routing rules and validate the output files.

---

## Quick Start

### For Basic Users

```bash
# Generate China routing rules (default target)
make

# Or explicitly:
make generate

# Clean temporary files
make clean

# Get help
make help
```

### For Developers

```bash
# Set up development environment
make dev-setup
source .make.d/setup.sh

# Use convenient aliases
cn-gen          # Generate routes
cn-clean        # Clean files
cn-bench        # Run benchmarks
cn-analyze      # Analyze outputs

# Run comprehensive tests
make ci-test
```

### For System Administrators

```bash
# Install system-wide (requires root)
sudo make install

# Set up automatic daily updates
sudo make service-setup

# Enable the service
sudo systemctl enable --now chnroute.timer

# Check service status
sudo systemctl status chnroute.timer
```

---

## Command Reference

### Basic Targets

#### `generate` (Default)
Generate China IP routes and GFW domain lists with full validation.

```bash
make generate
# or simply:
make
```

**What it does:**
- Checks all dependencies
- Validates script syntax
- Downloads latest data from sources
- Generates RouterOS configuration files
- Validates output files

**Output files created:**
- `CN.rsc` - China IP address list (permanent timeout)
- `CN_mem.rsc` - China IP address list (248-day timeout)
- `gfwlist_v7.rsc` - GFW domain rules for RouterOS v7+
- `gfwlist.txt` - Plain text domain list
- `03-gfwlist.conf` - dnsmasq configuration format

#### `fast`
Generate routes without dependency checks for faster execution.

```bash
make fast
```

**Use case:** When you're confident all dependencies are available and want maximum speed.

#### `clean`
Remove all temporary files and build artifacts.

```bash
make clean
```

**Files removed:**
- `logs/` directory
- `*.tmp` and `*.processed` files
- `chnroute_*` temporary directories
- `.make.d/` development files
- Various cache files

#### `check`
Verify dependencies and validate script syntax.

```bash
make check
```

**Components checked:**
- Required command availability
- Shell script syntax
- Optional tool warnings
- Configuration file validation

#### `validate`
Validate generated output files.

```bash
make validate
```

**Validation criteria:**
- File existence
- File size (non-empty)
- Basic format validation

#### `test`
Run comprehensive tests including generation and validation.

```bash
make test
```

**Test sequence:**
1. Generate routes
2. Validate all outputs
3. Display file statistics

#### `help`
Display comprehensive help information.

```bash
make help
```

Shows available targets, usage examples, and descriptions.

---

### Development Targets

#### `benchmark`
Measure generation performance with detailed timing.

```bash
make benchmark
```

**Features:**
- Cold cache timing
- Warm cache timing
- Average of 3 runs (if python3 available)
- GNU time integration for detailed metrics

**Example output:**
```
[12:34:56] Running performance benchmark...
  Cold cache run:
    real 0m45.234s  user 0m42.123s  sys 0m3.111s
  Warm cache run:
    real 0m15.678s  user 0m14.234s  sys 0m1.444s
  Average of 3 runs:
    Run 1: 15.234 s
    Run 2: 14.987 s
    Run 3: 15.123 s
  Average: 15.115 s
[12:35:41] [OK] Benchmark completed
```

#### `memory-profile`
Collect memory usage information during generation.

```bash
make memory-profile
```

**Requires:** GNU time (`/usr/bin/time`)

**Output includes:**
- Maximum resident set size
- User time
- System time
- CPU usage percentage

#### `analyze`
Analyze and summarize generated output files.

```bash
make analyze
```

**Provides statistics:**
- File sizes in bytes
- Line counts
- Total statistics

**Example output:**
```
[12:36:12] Analyzing output files...
  CN.rsc: 8923 lines, 245678 bytes
  CN_mem.rsc: 8923 lines, 245678 bytes
  gfwlist_v7.rsc: 2345 lines, 123456 bytes
  gfwlist.txt: 2345 lines, 45678 bytes
  03-gfwlist.conf: 4689 lines, 234567 bytes
  Totals: 27225 lines, 894075 bytes
```

#### `dev-setup`
Set up development environment with aliases and shell completion.

```bash
make dev-setup
```

**Creates:**
- `.make.d/aliases` - Shell aliases for common commands
- `.make.d/completion.bash` - Tab completion for make targets
- `.make.d/setup.sh` - Setup script to load environment

**After setup:**
```bash
source .make.d/setup.sh
```

**Available aliases:**
- `cn-gen` - `make generate`
- `cn-fast` - `make fast`
- `cn-clean` - `make clean`
- `cn-test` - `make test`
- `cn-bench` - `make benchmark`
- `cn-analyze` - `make analyze`

#### `ci-test`
Run a complete CI workflow for testing.

```bash
make ci-test
```

**Workflow:**
1. Clean previous builds
2. Check dependencies and syntax
3. Run comprehensive tests
4. Execute benchmarks
5. Analyze outputs

---

### System Targets

#### `install`
Install chnroute system-wide (requires root privileges).

```bash
sudo make install
```

**Installation locations:**
- `/opt/chnroute/` - Main program files
- `/etc/chnroute/` - Configuration files
- Scripts and data files with appropriate permissions
- Default configuration file created

#### `service-setup`
Configure systemd service for automatic daily updates.

```bash
sudo make service-setup
```

**Creates:**
- `/etc/systemd/system/chnroute.service` - Service unit
- `/etc/systemd/system/chnroute.timer` - Timer unit
- Reloads systemd daemon

**Service configuration:**
- Runs daily at a randomized time
- Persistent execution (catches up if missed)
- Runs as root user
- Proper environment and security settings

**After installation:**
```bash
# Enable and start the timer
sudo systemctl enable --now chnroute.timer

# Check status
sudo systemctl status chnroute.timer
sudo systemctl status chnroute.service

# View logs
journalctl -u chnroute.service -f
```

#### `uninstall`
Remove all installed files and services.

```bash
sudo make uninstall
```

**Removes:**
- All installed files
- Systemd service and timer units
- Configuration directories
- Reloads systemd daemon

#### `package`
Create a distributable archive for deployment.

```bash
make package
```

**Creates:**
- `dist/chnroute-<version>.tar.gz` - Complete package
- Includes all necessary files and documentation
- Package information file

**Package contents:**
- Generated output files
- Scripts and libraries
- Configuration files
- Documentation
- Package metadata

---

#### `info`
Display project information and current status.

```bash
make info
```

**Shows:**
- Project version
- Installation paths
- Output file statistics
- Repository information

---

## Usage Examples

### Everyday Usage

```bash
# Quick generation with validation
make

# Generate without dependency checks (faster)
make fast

# Clean up after generation
make clean && make generate

# Check if everything is working
make test
```

### Development Workflow

```bash
# 1. Set up development environment
make dev-setup
source .make.d/setup.sh

# 2. Make changes to scripts
vim generate.sh

# 3. Test changes
cn-gen
cn-test

# 4. Run performance tests
cn-bench

# 5. Analyze results
cn-analyze

# 6. Run full CI test
make ci-test
```

### System Administration

```bash
# 1. Install system-wide
sudo make install

# 2. Set up automatic updates
sudo make service-setup
sudo systemctl enable --now chnroute.timer

# 3. Monitor service
sudo systemctl status chnroute.timer
sudo journalctl -u chnroute.service --since "1 hour ago"

# 4. Manual update (if needed)
sudo systemctl start chnroute.service

# 5. Check logs
sudo journalctl -u chnroute.service -f

# 6. Update configuration
sudo vim /etc/chnroute/config.conf
sudo systemctl restart chnroute.service
```

### Troubleshooting

```bash
# 1. Check system dependencies
make check

# 2. Validate syntax
make validate-syntax

# 3. Run with detailed logging
bash generate.sh

# 4. Check system resources
make memory-profile

# 5. Clean and retry
make clean
make generate
```

### Performance Analysis

```bash
# 1. Baseline benchmark
make benchmark

# 2. Memory usage analysis
make memory-profile

# 3. Output analysis
make analyze

# 4. Create performance report
make benchmark > benchmark-report.txt
make analyze >> benchmark-report.txt
make memory-profile >> benchmark-report.txt
```

---

## Development Workflow

### For Contributors

1. **Setup Environment**
   ```bash
   git clone https://github.com/ruijzhan/chnroute.git
   cd chnroute
   make dev-setup
   source .make.d/setup.sh
   ```

2. **Development Cycle**
   ```bash
   # Make changes
   vim generate.sh

   # Test changes
   cn-test

   # Run full test suite
   make ci-test

   # Check performance impact
   cn-bench
   ```

3. **Quality Assurance**
   ```bash
   # Syntax checking
   make check

   # Static analysis (if shellcheck available)
   shellcheck *.sh

   # Manual testing
   make clean && make generate
   ```

4. **Create Package**
   ```bash
   make package
   # Test package in clean environment
   ```

### Performance Optimization

1. **Benchmark Current State**
   ```bash
   make benchmark > baseline.txt
   ```

2. **Implement Optimizations**
   ```bash
   # Make code changes
   ```

3. **Compare Performance**
   ```bash
   make benchmark > optimized.txt
   diff baseline.txt optimized.txt
   ```

4. **Memory Profiling**
   ```bash
   make memory-profile
   # Analyze memory usage patterns
   ```

---

## Troubleshooting

### Common Issues

#### Dependency Problems

**Problem:** `make check` reports missing tools

**Solution:**
```bash
# On Ubuntu/Debian
sudo apt-get update
sudo apt-get install bash curl awk grep sed coreutils tar

# On CentOS/RHEL
sudo yum install bash curl awk grep sed coreutils tar

# On macOS (using Homebrew)
brew install bash curl gnu-sed gnu-tar
```

#### Permission Issues

**Problem:** Permission denied during installation

**Solution:**
```bash
# Ensure using sudo for system targets
sudo make install
sudo make service-setup
```

#### Generation Failures

**Problem:** Route generation fails

**Troubleshooting steps:**
```bash
# 1. Check network connectivity
curl -I https://www.iwik.org/ipcountry/mikrotik/CN

# 2. Verify script syntax
make validate-syntax

# 3. Check disk space
df -h

# 4. Run with detailed output
bash -x generate.sh

# 5. Check logs
ls -la logs/
cat logs/*.log
```

#### Service Issues

**Problem:** Systemd service not working

**Troubleshooting:**
```bash
# Check service status
sudo systemctl status chnroute.service
sudo systemctl status chnroute.timer

# View logs
sudo journalctl -u chnroute.service -n 50

# Check timer schedule
sudo systemctl list-timers chnroute.timer

# Manual service start
sudo systemctl start chnroute.service
```

#### Performance Issues

**Problem:** Slow generation times

**Analysis:**
```bash
# Check system resources
free -h
df -h

# Run benchmarks
make benchmark

# Profile memory usage
make memory-profile

# Check network speed
curl -o /dev/null http://www.iwik.org/ipcountry/mikrotik/CN
```

### Debug Mode

For detailed debugging, run scripts directly:

```bash
# Enable debug logging
export LOG_LEVEL=DEBUG

# Run with bash debugging
bash -x generate.sh

# Monitor system resources
htop
iotop
```

### Getting Help

1. **Built-in help:**
   ```bash
   make help
   ```

2. **Version information:**
   ```bash
   make info
   ```

3. **Check configuration:**
   ```bash
   make check
   make validate-syntax
   ```

4. **GitHub Issues:**
   - Report bugs at: https://github.com/ruijzhan/chnroute/issues
   - Include system information and error logs

---

## Advanced Configuration

### Environment Variables

You can customize behavior using environment variables:

```bash
# Set log level
export LOG_LEVEL=DEBUG
make generate

# Skip validation for faster execution
export SKIP_VALIDATION=true
make fast

# Set custom thread count
export PARALLEL_THREADS=8
make generate

# Use custom DNS servers
export CUSTOM_DNS_SERVERS="8.8.8.8,1.1.1.1"
make generate
```

### Configuration Files

#### System Configuration
Edit `/etc/chnroute/config.conf` after installation:

```bash
sudo vim /etc/chnroute/config.conf
```

**Example configuration:**
```bash
# Log level: DEBUG, INFO, WARN, ERROR
LOG_LEVEL=INFO

# Parallel processing threads
PARALLEL_THREADS=4

# Custom DNS servers
CUSTOM_DNS_SERVERS=8.8.8.8,1.1.1.1

# Enable performance monitoring
ENABLE_PERFORMANCE_MONITORING=true
```

#### Domain Lists

Custom domain lists can be added by editing:

```bash
# Include additional domains
vim include_list.txt

# Exclude specific domains
vim exclude_list.txt

# Regenerate after changes
make generate
```

### Make Variables

You can override Makefile variables:

```bash
# Custom installation directory
sudo make install INSTALL_DIR=/usr/local/chnroute

# Custom script names
make generate SCRIPT=custom_generate.sh

# Custom output directory
make generate OUTPUT_DIR=/tmp/chnroute
```

### Parallel Execution

Control parallel execution:

```bash
# Limit parallel jobs
make -j2

# Use all CPU cores
make -j$(nproc)

# Disable parallel execution
make -j1
```

---

## Contributing

### Development Setup

1. **Fork and Clone**
   ```bash
   git clone https://github.com/yourusername/chnroute.git
   cd chnroute
   ```

2. **Setup Development Environment**
   ```bash
   make dev-setup
   source .make.d/setup.sh
   ```

3. **Create Feature Branch**
   ```bash
   git checkout -b feature-name
   ```

4. **Make Changes**
   ```bash
   # Edit files
   vim generate.sh

   # Test changes
   cn-test
   make ci-test
   ```

5. **Run Quality Checks**
   ```bash
   make check
   shellcheck *.sh
   make benchmark
   ```

6. **Commit Changes**
   ```bash
   git add .
   git commit -m "Description of changes"
   ```

7. **Test Package Creation**
   ```bash
   make package
   # Test the package
   ```

8. **Push and Create Pull Request**
   ```bash
   git push origin feature-name
   # Create pull request on GitHub
   ```

### Code Style

- Follow existing code formatting
- Use meaningful variable names
- Add comments for complex logic
- Ensure all functions have proper error handling
- Test all changes before submitting

### Testing

- Run `make ci-test` before committing
- Test on multiple systems if possible
- Verify performance doesn't degrade
- Check that all output files are generated correctly

### Documentation

- Update this guide for new features
- Add examples for new targets
- Update help text in Makefile
- Document any breaking changes

---

## Performance Tuning

### System Optimization

1. **Memory Configuration**
   ```bash
   # Ensure sufficient memory
   free -h

   # Use tmpfs for temporary files if RAM available
   sudo mount -t tmpfs -o size=1G tmpfs /tmp
   ```

2. **Network Optimization**
   ```bash
   # Test network speed to data sources
   curl -o /dev/null http://www.iwik.org/ipcountry/mikrotik/CN

   # Use local DNS caching
   sudo systemctl enable --now dnsmasq
   ```

3. **CPU Optimization**
   ```bash
   # Monitor CPU usage
   htop

   # Adjust thread count based on CPU cores
   export PARALLEL_THREADS=$(nproc)
   ```

### Benchmarking

Regular performance monitoring:

```bash
# Create benchmark history
mkdir -p benchmarks
make benchmark > "benchmarks/benchmark-$(date +%Y%m%d-%H%M%S).txt"

# Compare performance over time
diff benchmarks/benchmark-20240101-120000.txt benchmarks/benchmark-20240102-120000.txt
```

### Optimization Strategies

1. **Caching**: Enable local caching of downloaded data
2. **Parallel Processing**: Adjust thread count based on system resources
3. **Network Optimization**: Use local mirrors or CDNs when available
4. **Memory Management**: Monitor and optimize memory usage patterns

---

## Security Considerations

### Network Security

- Downloads use HTTPS when available
- TLS certificate validation enabled by default
- User-Agent headers identify the client appropriately

### File Permissions

- Scripts execute with current user permissions
- System installation uses appropriate permissions (755 for scripts, 644 for data)
- Configuration files protected with appropriate permissions

### System Integration

- Systemd services run with minimal required privileges
- Environment variables are explicitly set
- File paths are validated to prevent directory traversal

### Recommendations

1. **Regular Updates**: Keep scripts and dependencies updated
2. **Monitoring**: Monitor system logs for unusual activity
3. **Access Control**: Limit who can modify configuration files
4. **Audit Trail**: Enable logging for production deployments

---

## FAQ

### Q: How often should I run the generation?
A: For most users, daily automatic updates via the systemd timer are sufficient. The timer is configured to run once per day with randomized timing to avoid server load peaks.

### Q: Can I customize the generated RouterOS scripts?
A: Yes, you can modify the templates in the `lib/processor.sh` file, but be sure to test changes thoroughly before deploying.

### Q: What if the download sources are unavailable?
A: The Makefile includes retry logic and timeout handling. If sources remain unavailable, consider using cached data or alternative mirrors.

### Q: How can I reduce memory usage during generation?
A: You can reduce the `PARALLEL_THREADS` environment variable, or use the `fast` target which skips some validation steps.

### Q: Can I use this on non-Linux systems?
A: The Makefile is primarily designed for Linux but may work on other Unix-like systems with modifications. Systemd targets require Linux.

### Q: How do I backup my configuration?
A: Backup the configuration directory and any custom domain lists:
   ```bash
   sudo cp -r /etc/chnroute /path/to/backup/
   ```

### Q: Can I run multiple instances simultaneously?
A: It's not recommended as it may cause conflicts. The temporary directory system uses unique names but output files would conflict.

---

## Support and Community

### Getting Help

- **Documentation**: This guide and the `make help` command
- **Issues**: GitHub Issues at https://github.com/ruijzhan/chnroute/issues
- **Discussions**: GitHub Discussions for general questions
- **Wiki**: Project wiki for additional documentation

### Contributing

We welcome contributions! Please see the [Contributing](#contributing) section for guidelines.

### License

This project is licensed under the terms specified in the repository's LICENSE file.

---

*Last updated: $(date '+%Y-%m-%d')*