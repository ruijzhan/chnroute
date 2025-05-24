#!/usr/bin/env bash

# Script to generate RouterOS configuration files for China IP routes and GFW domain lists
# Author: ruijzhan
# Repository: https://github.com/ruijzhan/chnroute

set -euo pipefail

export LC_ALL=POSIX

# Configuration constants
readonly GFWLIST2DNSMASQ_SH="gfwlist2dnsmasq.sh"
readonly INCLUDE_LIST_TXT="include_list.txt"
readonly EXCLUDE_LIST_TXT="exclude_list.txt"
readonly GFWLIST="gfwlist.txt"
readonly LIST_NAME="gfw_list"
readonly DNS_SERVER="\$dnsserver"
readonly GFWLIST_V7_RSC="gfwlist_v7.rsc"
readonly CN_RSC="CN.rsc"
readonly CN_IN_MEM_RSC="CN_mem.rsc"
readonly GFWLIST_CONF="03-gfwlist.conf"

# Source URLs
readonly CN_URL="http://www.iwik.org/ipcountry/mikrotik/CN"
readonly GFWLIST_URL="https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt"
readonly OUTPUT_GFWLIST_AUTOPROXY="gfwlist_autoproxy.txt"

# Temporary files
readonly TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

# Logging functions with timestamps
log_info() {
    printf "[%s] [INFO] %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$1"
}

log_error() {
    printf "[%s] [ERROR] %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$1" >&2
}

log_warn() {
    printf "[%s] [WARN] %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$1" >&2
}

log_success() {
    printf "[%s] [SUCCESS] %s\n" "$(date +"%Y-%m-%d %H:%M:%S")" "$1"
}

# Sort and validate domain lists
sort_files() {
    log_info "Sorting and validating domain lists..."
    
    # Check if files exist, create if they don't
    for file in "$INCLUDE_LIST_TXT" "$EXCLUDE_LIST_TXT"; do
        if [[ ! -f "$file" ]]; then
            log_warn "$file not found, creating empty file"
            touch "$file"
        fi
    done
    
    # Sort and remove duplicates
    sort -uo "$INCLUDE_LIST_TXT" "$INCLUDE_LIST_TXT"
    sort -uo "$EXCLUDE_LIST_TXT" "$EXCLUDE_LIST_TXT"
    
    # Count domains
    local include_count exclude_count
    include_count=$(wc -l < "$INCLUDE_LIST_TXT")
    exclude_count=$(wc -l < "$EXCLUDE_LIST_TXT")
    log_info "Domain lists processed: $include_count domains to include, $exclude_count domains to exclude"
}

# Run gfwlist2dnsmasq to generate gfwlist with error handling (silent mode)
run_gfwlist2dnsmasq() {
    log_info "Running gfwlist2dnsmasq to generate domain list..."
    
    # Check if gfwlist2dnsmasq.sh exists
    if [[ ! -f "$GFWLIST2DNSMASQ_SH" ]]; then
        log_error "$GFWLIST2DNSMASQ_SH not found"
        return 1
    fi
    
    # Check if gfwlist_autoproxy.txt exists
    if [[ ! -f "$OUTPUT_GFWLIST_AUTOPROXY" ]]; then
        log_error "$OUTPUT_GFWLIST_AUTOPROXY not found. Run parallel_downloads first."
        return 1
    fi
    
    # Create a log file for the output in our temp directory
    local log_file="${TMP_DIR}/gfwlist2dnsmasq.log"
    
    # Run gfwlist2dnsmasq.sh with appropriate options, redirecting all output to the log file
    if bash "$GFWLIST2DNSMASQ_SH" \
        --domain-list \
        --extra-domain-file "$INCLUDE_LIST_TXT" \
        --exclude-domain-file "$EXCLUDE_LIST_TXT" \
        --output "$GFWLIST" > "$log_file" 2>&1; then
        
        local domain_count
        domain_count=$(wc -l < "$GFWLIST")
        log_success "Generated gfwlist with $domain_count domains"
    else
        local exit_code=$?
        log_error "Failed to generate gfwlist (exit code: $exit_code)"
        log_error "Check log file for details: $log_file"
        return 1
    fi
}

# Create gfwlist rsc file with improved performance and error handling
create_gfwlist_rsc() {
    local version="$1"
    local output_rsc="$2"
    local input_file="$GFWLIST"
    
    # Check if input file exists
    if [[ ! -f "$input_file" ]]; then
        log_error "Input file $input_file not found"
        return 1
    fi
    
    log_info "Creating RouterOS script $output_rsc for version $version..."
    
    # Create a temporary file in our managed temp directory
    local tmp_file="${TMP_DIR}/$(basename "$output_rsc")"
    
    # Write header to the temporary file
    cat <<EOL >"$tmp_file"
# RouterOS script for GFW domain list - Version $version
# Source: https://github.com/ruijzhan/chnroute

:global dnsserver
/ip dns static remove [/ip dns static find forward-to=\$dnsserver ]
/ip dns static
:local domainList {
EOL
    
    # Count domains for progress reporting
    local domain_count
    domain_count=$(wc -l < "$input_file")
    log_info "Processing $domain_count domains..."
    
    # Process domains in batches for better performance
    # Use awk for faster processing instead of reading line by line
    awk '{print "    \""$0"\";"}' "$input_file" >> "$tmp_file"
    
    # Write footer to the temporary file
    cat <<EOL >>"$tmp_file"
}

# Add each domain to DNS static entries
:foreach domain in=\$domainList do={
    /ip dns static add forward-to=\$dnsserver type=FWD address-list=gfw_list match-subdomain=yes name=\$domain
}

# Flush DNS cache to apply changes
/ip dns cache flush

# Log completion
/log info "GFW domain list updated with $domain_count domains"
EOL
    
    # Move the temporary file to the output file
    mv "$tmp_file" "$output_rsc"
    
    log_success "Created $output_rsc with $domain_count domains"
    return 0
}

# Check if there are any changes in the git repository
check_git_status() {
    log_info "Checking git status..."
    
    # Check if we're in a git repository
    if ! git rev-parse --is-inside-work-tree &>/dev/null; then
        log_warn "Not in a git repository, skipping git status check"
        return 0
    fi
    
    # Check if GFWLIST_CONF exists and is tracked by git
    if [[ ! -f "$GFWLIST_CONF" ]] || ! git ls-files --error-unmatch "$GFWLIST_CONF" &>/dev/null; then
        log_warn "$GFWLIST_CONF is not tracked by git, skipping checkout"
        return 0
    fi
    
    # Check if there's only one change in the git repository
    if [[ $(git status -s | wc -l) -eq 1 ]]; then
        log_info "Only one change detected, checking out $GFWLIST_CONF"
        if git checkout "$GFWLIST_CONF"; then
            log_success "Successfully checked out $GFWLIST_CONF"
        else
            log_error "Failed to checkout $GFWLIST_CONF"
            return 1
        fi
    else
        log_info "Multiple changes detected, not checking out $GFWLIST_CONF"
    fi
    
    return 0
}

# Generate CN IP list with improved error handling and performance
generate_cn_ip_list() {
    local input_file="$1"
    local output_file="$2"
    local timeout="$3"

    # Check the number of parameters
    if [ "$#" -ne 3 ]; then
        log_error "Usage: generate_cn_ip_list <input file> <output file> <timeout>"
        return 1
    fi

    # Check if input file exists
    if [ ! -f "$input_file" ]; then
        log_error "Input file '$input_file' does not exist"
        return 1
    fi

    log_info "Generating CN IP list from $input_file to $output_file with timeout $timeout"

    # Create a temporary file in our managed temp directory
    local tmp_file="${TMP_DIR}/$(basename "$output_file")"

    # Use heredoc to write the initial part to the temporary file
    cat <<EOL > "$tmp_file"
/log info "Loading CN ipv4 address list"
/ip firewall address-list remove [/ip firewall address-list find list=CN]
/ip firewall address-list
:local ipList {
EOL

    # Read the input file, extract IP addresses and subnets, and write them to ipList
    # Use grep for faster pattern matching and awk for formatting
    grep -o 'address=[0-9./]\+' "$input_file" | \
        awk -F= '{print "    \"" $2 "\";"}' >> "$tmp_file" || {
        log_error "Failed to extract IP addresses from $input_file"
        return 1
    }

    # Count the number of IP addresses extracted
    local ip_count
    ip_count=$(grep -c '"[0-9./]\+";' "$tmp_file" || echo 0)
    
    if [ "$ip_count" -eq 0 ]; then
        log_error "No IP addresses found in $input_file"
        return 1
    fi

    # Write the loop part to the temporary file
    cat <<EOL >> "$tmp_file"
}
:foreach ip in=\$ipList do={
    /ip firewall address-list add address=\$ip list=CN timeout=$timeout
}
EOL

    # Move the temporary file to the output file
    mv "$tmp_file" "$output_file"

    log_success "CN IP list generated successfully with $ip_count IP addresses to $output_file"
    return 0
}

# Modify CN.rsc to create versions with different timeouts
modify_cn_rsc() {
    local input_file="$CN_RSC"
    local output_file="$CN_IN_MEM_RSC"
    
    log_info "Modifying CN.rsc to create versions with different timeouts..."
    
    # Check if input file exists
    if [[ ! -f "$input_file" ]]; then
        log_error "Input file $input_file not found"
        return 1
    fi
    
    # Create in-memory version with 248-day timeout
    log_info "Creating in-memory version with 248-day timeout: $output_file"
    if generate_cn_ip_list "$input_file" "$output_file" "248d"; then
        log_success "Successfully created in-memory version: $output_file"
    else
        log_error "Failed to create in-memory version"
        return 1
    fi
    
    # Create permanent version with 0 timeout
    log_info "Creating permanent version with 0 timeout: $input_file"
    if generate_cn_ip_list "$input_file" "${TMP_DIR}/$(basename "$input_file")" "0"; then
        mv "${TMP_DIR}/$(basename "$input_file")" "$input_file"
        log_success "Successfully updated permanent version: $input_file"
    else
        log_error "Failed to update permanent version"
        return 1
    fi
    
    return 0
}

# Enhanced cleanup function to remove all temporary files
cleanup() {
    log_info "Cleaning up temporary files..."
    
    # The TMP_DIR is already set to be removed by the trap at the top of the script
    # This function handles any additional cleanup needed
    
    # List of specific files to clean up
    local files_to_clean=("$OUTPUT_GFWLIST_AUTOPROXY")
    
    # Remove each file if it exists
    for file in "${files_to_clean[@]}"; do
        if [[ -f "$file" ]]; then
            rm -f "$file"
            log_info "Removed temporary file: $file"
        fi
    done
}

trap cleanup EXIT

# Enhanced download function with retries, timeout, and progress indication
# Usage: download_with_retry <url> <output_file> [timeout_seconds]
download_with_retry() {
    local url="$1"
    local output="$2"
    local timeout=${3:-30}  # Default timeout: 30 seconds
    local max_retries=3
    local retry_count=0
    local retry_delay=2
    
    log_info "Downloading $url to $output"
    
    while ((retry_count < max_retries)); do
        if curl -fsSL --connect-timeout "$timeout" --retry 3 --retry-delay 2 \
                --retry-max-time $((timeout * 2)) \
                -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36" \
                "$url" -o "$output"; then
            log_success "Downloaded $url to $output"
            return 0
        fi
        
        local curl_exit=$?
        ((retry_count++))
        
        if [[ $retry_count -lt $max_retries ]]; then
            log_warn "Download failed with exit code $curl_exit. Retry $retry_count/$max_retries for $url in $retry_delay seconds"
            sleep $retry_delay
            # Increase retry delay exponentially
            retry_delay=$((retry_delay * 2))
        else
            log_error "Failed to download $url after $max_retries attempts"
        fi
    done
    
    return 1
}

# Parallelize downloads with robust retry logic and improved error handling
declare -a PARALLEL_PIDS=()
parallel_downloads() {
    log_info "Starting parallel downloads..."
    local download_success=true
    local cn_success=false
    local gfwlist_success=false
    
    # Create a named pipe for status updates
    local status_pipe="${TMP_DIR}/status_pipe"
    mkfifo "$status_pipe"
    
    # Download CN.rsc in background with retry
    (
        if download_with_retry "$CN_URL" "$CN_RSC" 60; then
            echo "cn_success" > "$status_pipe"
        else
            echo "cn_failed" > "$status_pipe"
        fi
    ) &
    PARALLEL_PIDS+=("$!")
    
    # Download gfwlist in background with retry and decode after download
    (
        local tmp_base64_file="${TMP_DIR}/gfwlist.base64"
        if download_with_retry "$GFWLIST_URL" "$tmp_base64_file" 60; then
            if base64 --decode "$tmp_base64_file" > "$OUTPUT_GFWLIST_AUTOPROXY"; then
                log_success "Decoded content saved to $OUTPUT_GFWLIST_AUTOPROXY"
                echo "gfwlist_success" > "$status_pipe"
            else
                log_error "Failed to decode base64 for gfwlist"
                echo "gfwlist_failed" > "$status_pipe"
            fi
        else
            log_error "Failed to download gfwlist"
            echo "gfwlist_failed" > "$status_pipe"
        fi
    ) &
    PARALLEL_PIDS+=("$!")
    
    # Process status updates
    for i in {1..2}; do
        local status
        read -r status < "$status_pipe"
        case "$status" in
            "cn_success")
                cn_success=true
                log_success "CN.rsc download completed successfully"
                ;;
            "cn_failed")
                download_success=false
                log_error "CN.rsc download failed"
                ;;
            "gfwlist_success")
                gfwlist_success=true
                log_success "GFWList download and decode completed successfully"
                ;;
            "gfwlist_failed")
                download_success=false
                log_error "GFWList download or decode failed"
                ;;
        esac
    done
    
    # Wait for all background processes to complete
    for pid in "${PARALLEL_PIDS[@]}"; do
        wait "$pid" || download_success=false
    done
    
    # Clean up named pipe
    rm -f "$status_pipe"
    
    # Proceed only if both downloads were successful
    if $download_success; then
        log_success "All downloads completed successfully"
        if $cn_success; then
            modify_cn_rsc
        fi
    else
        log_error "Some downloads failed, check logs for details"
        return 1
    fi
}

# Enhanced main function with better error handling and execution flow
main() {
    local start_time=$(date +%s)
    local exit_code=0
    
    log_info "Starting chnroute generation process..."
    
    # Step 1: Download resources in parallel first
    log_info "Step 1/5: Downloading resources"
    if ! parallel_downloads; then
        log_error "Failed to download resources"
        exit_code=1
    fi
    
    # Step 2: Sort and validate domain lists
    log_info "Step 2/5: Sorting and validating domain lists"
    if ! sort_files; then
        log_warn "Issues with domain lists, but continuing"
    fi
    
    # Step 3: Generate GFW list
    log_info "Step 3/5: Generating GFW list"
    if ! run_gfwlist2dnsmasq; then
        log_error "Failed to generate GFW list"
        exit_code=1
    fi
    
    # Step 4: Create RouterOS scripts
    if [[ $exit_code -eq 0 ]]; then
        log_info "Step 4/5: Creating RouterOS scripts"
        if ! create_gfwlist_rsc "v7" "$GFWLIST_V7_RSC"; then
            log_error "Failed to create RouterOS scripts"
            exit_code=1
        fi
    fi
    
    # Step 5: Check git status
    log_info "Step 5/5: Checking git status"
    if ! check_git_status; then
        log_warn "Issues with git status check, but continuing"
    fi
    
    # Calculate execution time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "All tasks completed successfully in $duration seconds"
    else
        log_error "Some tasks failed, check logs for details. Execution time: $duration seconds"
    fi
    
    return $exit_code
}

# Execute main function
main