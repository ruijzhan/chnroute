#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=tests/test_framework.sh
. "${SCRIPT_DIR}/test_framework.sh"

status=0

for test_file in "${SCRIPT_DIR}"/test_*.sh; do
    if [[ "$(basename "$test_file")" == "test_framework.sh" ]]; then
        continue
    fi
    printf "\nRunning %s...\n" "$(basename "$test_file")"
    # shellcheck disable=SC1090
    if ! . "$test_file"; then
        status=1
    fi
done

if ! print_test_summary; then
    status=1
fi

exit "$status"

