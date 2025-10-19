# Repository Guidelines

## Project Structure & Module Organization
- **Core Scripts**:
  - `generate.sh`: main pipeline using modular lib/ architecture; produces `CN.rsc`, `CN_mem.rsc`, `gfwlist_v7.rsc`, `03-gfwlist.conf`, `gfwlist.txt`.
  - `gfwlist2dnsmasq.sh`: converts gfwlist to dnsmasq rules or a plain domain list.
  - `generate_cn.sh`: optional/legacy helper.
- **Library Modules (`lib/`)**:
  - `config.sh`: Central configuration, constants, and metadata
  - `logger.sh`: Logging utilities with color output and levels
  - `downloader.sh`: Network downloads with retry logic and error handling
  - `processor.sh`: Parallel data processing and domain formatting
  - `validation.sh`: Input validation and file existence checking
  - `error.sh`: Error handling utilities and cleanup functions
  - `temp.sh`: Temporary file management and cleanup
  - `platform.sh`: Platform detection and compatibility
  - `dependencies.sh`: Dependency checking and validation
  - `resources.sh`: External resource URLs and data sources
- **Configuration Files**: `include_list.txt` (add domains), `exclude_list.txt` (remove domains).
- **CI/CD**: `.github/workflows/main.yaml` runs `make` daily and commits updates.
- **Documentation**: `README.md`, `README.en.md`, `CLAUDE.md` for usage and RouterOS examples.

## Build, Test, and Development Commands

### Core Commands
- **Build/Update**: `make` or `make generate` — downloads sources and regenerates all artifacts.
- **Fast Build**: `make fast` — generation without dependency checks (for development).
- **Direct Execution**: `bash generate.sh` or `bash gfwlist2dnsmasq.sh`.

### Testing & Validation
- **Syntax Check**: `make check` — verify dependencies and shell script syntax.
- **Output Validation**: `make validate` or `make validate-output` — confirm generated files exist and are non-empty.
- **Full Test Suite**: `make test` — run generation and validate outputs.
- **CI Workflow**: `make ci-test` — comprehensive local CI (clean, check, test, benchmark, analyze).

### Development Tools
- **Performance**: `make benchmark` — timing analysis and performance metrics.
- **Analysis**: `make analyze` — file sizes and line counts summary.
- **Memory Profile**: `make memory-profile` — memory usage during generation.
- **Development Setup**: `make dev-setup` — aliases and shell completion.
- **Cleanup**: `make clean` — remove temporary files and artifacts.

### Examples
- **Domain List Only**: `bash gfwlist2dnsmasq.sh -l -o gfwlist.txt --extra-domain-file include_list.txt --exclude-domain-file exclude_list.txt`.
- **Manual Lint**: `shellcheck generate.sh gfwlist2dnsmasq.sh`.
- **Quick Sanity Check**: `wc -l gfwlist.txt && head -n 5 gfwlist.txt`.

### Network Requirements
- Generators require network access; configure proxies via environment variables if needed.
- Parallel downloads with retry logic for improved reliability.

## Coding Style & Naming Conventions

### Shell Script Standards
- **Shebang & Strict Mode**: Use `#!/usr/bin/env bash` with `set -euo pipefail`.
- **Indentation**: 4-space indentation, no tabs.
- **Naming**: Functions `lower_snake_case`; constants `UPPER_SNAKE_CASE`; variables `lower_snake_case`.
- **Quoting**: Always quote variables: `"$var"` not `$var`.
- **Locale**: Keep `LC_ALL=POSIX` for consistent behavior.

### Code Organization
- **Modular Design**: Use lib/ directory for reusable modules.
- **Error Handling**: Implement proper error handling with traps and cleanup functions.
- **Temp Files**: Use `mktemp` and `trap` for safe temporary file management.
- **Pipelines**: Prefer awk/sed/grep pipelines over external dependencies.
- **Dependencies**: Minimize external runtime dependencies; use standard Unix tools.

### File Editing Guidelines
- **Generated Files**: Never hand-edit generated `.rsc/.conf/.txt` files.
- **Configuration**: Modify scripts or use `include_list.txt`/`exclude_list.txt` for customization.
- **Library Imports**: Use consistent sourcing pattern: `. "${LIB_DIR}/module.sh"`.
- **Documentation**: Include function documentation in library modules.

## Testing Guidelines

### Validation Approach
- **No Unit Test Framework**: Validation through functional testing and artifact verification.
- **Primary Test**: Run `make` or `make test` and confirm all expected files exist and are non-empty.
- **Output Verification**: Use `make validate` to check generated artifacts are properly formed.

### Domain Handling Testing
- **Include/Exclude Lists**: Add sample entries to `include_list.txt`/`exclude_list.txt` and re-run generation.
- **Domain Processing**: Verify domain formatting and filtering works as expected.
- **Edge Cases**: Test with empty lists and special domain formats.

### Manual Testing
- **RouterOS Import**: Manual testing of RouterOS script import and behavior.
- **Network Scenarios**: Test with various network conditions and proxy configurations.
- **Output Quality**: Review generated files for correctness and formatting.

### Test Artifacts
- **Do Not Commit**: Never commit device-specific outputs or test results.
- **Temporary Files**: Use proper cleanup during testing.
- **Performance**: Monitor performance changes with `make benchmark`.

## Commit & Pull Request Guidelines

### Commit Standards
- **Conventional Commits**: Use concise conventional style:
  - `feat(generate): add parallel processing support`
  - `fix(downloader): improve retry logic for network timeouts`
  - `docs(readme): update installation instructions`
  - `refactor(processor): optimize domain formatting`
- **CI Commits**: Automated updates use format: `Automated update: YYYY-MM-DD HH:MM:SS`.
- **Scope**: Focus on single logical changes per commit.

### Pull Request Requirements
- **Description**: Explain what changes were made and why they are necessary.
- **Evidence**: Include sample command output (e.g., `wc -l gfwlist.txt`) to show results.
- **Artifacts**: State whether generated artifacts were regenerated.
- **Testing**: Describe testing performed and results.

### Generated Files Policy
- **Prefer CI**: Generally avoid committing generated files; let CI refresh them after merge.
- **Exceptions**: Commit generated files only when necessary for documentation or critical fixes.
- **Consistency**: Ensure any committed artifacts match current generation logic.

### Review Process
- **Code Review**: Focus on logic changes, error handling, and performance.
- **Testing**: Verify that `make test` passes and outputs are reasonable.
- **Documentation**: Update relevant documentation when changing behavior.

## Security & Configuration Tips

### Security Practices
- **No Secrets**: Never hardcode secrets, API keys, or credentials.
- **Public Sources Only**: Scripts fetch from public sources; no authentication required.
- **Input Validation**: Validate all inputs and handle malformed data gracefully.
- **Safe Temp Files**: Use secure temporary file creation with proper permissions.

### Portability & Compatibility
- **Standard Environment**: Maintain compatibility with Ubuntu-latest (CI environment).
- **Minimal Dependencies**: Avoid adding runtime dependencies beyond standard Unix tools.
- **Cross-Platform**: Ensure scripts work across different Linux distributions.
- **Shell Compatibility**: Target bash 4.0+ features for maximum compatibility.

### Network Configuration
- **Proxy Support**: Configure proxies via standard environment variables (`http_proxy`, `https_proxy`).
- **Timeouts**: Implement reasonable connection and read timeouts.
- **Retry Logic**: Handle network failures gracefully with exponential backoff.
- **User Agent**: Use appropriate user agent strings for web requests.

### Performance & Resource Management
- **Memory Efficiency**: Use streaming processing for large files.
- **Parallel Processing**: Implement thread-safe operations where beneficial.
- **Cleanup**: Ensure proper cleanup of temporary files and resources.
- **Error Recovery**: Implement graceful degradation when external resources fail.

