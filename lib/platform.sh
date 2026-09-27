#!/usr/bin/env bash
# shellcheck shell=bash

# Platform compatibility helpers.

setup_platform_specific() {
    # macOS/BSD base64 uses -D to decode; everything else uses -d.
    case "$(uname -s)" in
        Darwin) BASE64_DECODE='base64 -D' ;;
        *) BASE64_DECODE='base64 -d' ;;
    esac

    DATE_FORMAT=$(date -Iseconds 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S%z')
}
