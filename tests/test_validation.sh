#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"

if [[ -z "${TESTS_PASSED+x}" ]]; then
    # shellcheck source=tests/test_framework.sh
    . "${SCRIPT_DIR}/test_framework.sh"
fi

# Another test file may have sourced these already; readonly declarations in
# logger.sh make a second sourcing fail.
if [[ -z "${COLOR_RESET+x}" ]]; then
    # shellcheck source=lib/logger.sh
    . "${LIB_DIR}/logger.sh"
fi
if ! declare -F validate_min_count >/dev/null; then
    # shellcheck source=lib/validation.sh
    . "${LIB_DIR}/validation.sh"
fi

test_validate_min_count_accepts_enough() {
    local status=0
    validate_min_count 1000 1000 "test list" >/dev/null || status=$?
    assert_equals "0" "$status" "count at the floor passes"
}

test_validate_min_count_rejects_too_few() {
    local status=0
    validate_min_count 999 1000 "test list" >/dev/null || status=$?
    assert_equals "1" "$status" "count below the floor fails"
}

test_validate_min_count_accepts_enough
test_validate_min_count_rejects_too_few
