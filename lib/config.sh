#!/usr/bin/env bash
# shellcheck shell=bash

# Shared configuration values for chnroute scripts.

# Script metadata
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_AUTHOR="ruijzhan"
readonly SCRIPT_REPO="https://github.com/ruijzhan/chnroute"

# Network defaults
readonly DEFAULT_CONNECT_TIMEOUT=30
readonly DEFAULT_RETRY_COUNT=3
readonly DEFAULT_RETRY_DELAY=2
readonly DEFAULT_RETRY_MAX_TIME_FACTOR=2

# Performance defaults
readonly DEFAULT_THREAD_COUNT=4
readonly MAX_THREAD_COUNT=8
readonly TEMP_FILE_PREFIX="chnroute_"

# Logging disabled - output to stdout only
# readonly LOG_DIR_NAME="logs"

# File paths
readonly INCLUDE_LIST_TXT="include_list.txt"
readonly EXCLUDE_LIST_TXT="exclude_list.txt"
readonly GFWLIST_TXT="gfwlist.txt"
readonly GFWLIST_V7_RSC="gfwlist_v7.rsc"
readonly CN_RSC="CN.rsc"
readonly CN_MEM_RSC="CN_mem.rsc"
readonly GFWLIST_CONF="03-gfwlist.conf"
readonly GFWLIST2DNSMASQ_SH="gfwlist2dnsmasq.sh"
readonly OUTPUT_GFWLIST_AUTOPROXY="gfwlist_autoproxy.txt"

# RouterOS specific defaults
readonly LIST_NAME="gfw_list"
readonly DNS_SERVER="\$dnsserver"

# Source URLs
readonly CN_URL="http://www.iwik.org/ipcountry/mikrotik/CN"
readonly GFWLIST_URL="https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt"

