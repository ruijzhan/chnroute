#!/usr/bin/env bash

set -euo pipefail

TESTS_PASSED=0
TESTS_FAILED=0

assert_equals() {
    local expected=$1
    local actual=$2
    local test_name=$3

    if [[ "$expected" == "$actual" ]]; then
        printf "✓ PASS: %s\n" "$test_name"
        ((TESTS_PASSED++)) || true
    else
        printf "✗ FAIL: %s\n" "$test_name"
        printf "  Expected: %s\n" "$expected"
        printf "  Actual:   %s\n" "$actual"
        ((TESTS_FAILED++)) || true
    fi
}

assert_file_exists() {
    local file=$1
    local test_name=$2

    if [[ -f "$file" ]]; then
        printf "✓ PASS: %s\n" "$test_name"
        ((TESTS_PASSED++)) || true
    else
        printf "✗ FAIL: %s\n" "$test_name"
        printf "  File does not exist: %s\n" "$file"
        ((TESTS_FAILED++)) || true
    fi
}

print_test_summary() {
    printf "\nTests passed: %d\n" "$TESTS_PASSED"
    printf "Tests failed: %d\n" "$TESTS_FAILED"
    printf "Total tests:  %d\n" $((TESTS_PASSED + TESTS_FAILED))

    if (( TESTS_FAILED == 0 )); then
        printf "All tests passed! ✓\n"
        return 0
    else
        printf "Some tests failed. ✗\n"
        return 1
    fi
}
