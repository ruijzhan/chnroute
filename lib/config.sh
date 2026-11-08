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

readonly TEMP_FILE_PREFIX="chnroute_"

# File paths
readonly INCLUDE_LIST_TXT="include_list.txt"
readonly EXCLUDE_LIST_TXT="exclude_list.txt"
readonly GFWLIST_TXT="gfwlist.txt"
readonly GFWLIST_V7_RSC="gfwlist_v7.rsc"
readonly CN_RSC="CN.rsc"
readonly CN_MEM_RSC="CN_mem.rsc"

# RouterOS specific defaults
readonly LIST_NAME="gfw_list"
readonly DNS_SERVER="\$dnsserver"

# dnsmasq artifact (03-gfwlist.conf)
readonly DNSMASQ_CONF="03-gfwlist.conf"
readonly DNSMASQ_DNS="8.8.8.8"
readonly DNSMASQ_PORT="53"

# Sanity floors: an upstream format change or a truncated download would
# otherwise yield a "successful" run and a committed, near-empty rule set.
readonly MIN_DOMAIN_COUNT=1000
readonly MIN_CN_IP_COUNT=5000

# Source URLs
readonly CN_URL="https://www.iwik.org/ipcountry/mikrotik/CN"
readonly GFWLIST_URL="https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt"

