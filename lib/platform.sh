#!/usr/bin/env bash
# shellcheck shell=bash

# Platform detection helpers.

detect_platform() {
    local os_type arch_type id
    os_type=$(uname -s)
    arch_type=$(uname -m)

    case "$os_type" in
        Darwin)
            echo "macos-${arch_type}"
            ;;
        Linux)
            if [[ -f /etc/os-release ]]; then
                # shellcheck disable=SC1091
                . /etc/os-release
                id=${ID:-unknown}
            else
                id="unknown"
            fi
            echo "linux-${id}-${arch_type}"
            ;;
        FreeBSD|OpenBSD|NetBSD)
            echo "bsd-${os_type}-${arch_type}"
            ;;
        *)
            echo "unknown-${os_type}-${arch_type}"
            ;;
    esac
}

setup_platform_specific() {
    local platform
    platform=$(detect_platform)

    case "$platform" in
        macos-*)
            BASE64_DECODE='base64 -D'
            SED_ERES='sed -E'
            ;;
        linux-*)
            BASE64_DECODE='base64 -d'
            SED_ERES='sed -r'
            ;;
        bsd-*)
            BASE64_DECODE='base64 -d'
            SED_ERES='sed -E'
            ;;
        *)
            BASE64_DECODE='base64 -d'
            SED_ERES='sed -r'
            ;;
    esac

    DATE_FORMAT=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S%z')
    log_info "Platform detected: ${platform}"
}

