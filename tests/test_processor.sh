#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB_DIR="${PROJECT_ROOT}/lib"

if [[ -z "${TESTS_PASSED+x}" ]]; then
    # shellcheck source=tests/test_framework.sh
    . "${SCRIPT_DIR}/test_framework.sh"
fi

# shellcheck source=lib/config.sh
. "${LIB_DIR}/config.sh"
# shellcheck source=lib/logger.sh
. "${LIB_DIR}/logger.sh"

# Reduce noise during tests
LOG_LEVEL=$LOG_LEVEL_ERROR
# shellcheck source=lib/temp.sh
. "${LIB_DIR}/temp.sh"
# shellcheck source=lib/error.sh
. "${LIB_DIR}/error.sh"
# shellcheck source=lib/validation.sh
. "${LIB_DIR}/validation.sh"
# shellcheck source=lib/processor.sh
. "${LIB_DIR}/processor.sh"

create_temp_root

test_process_domains_parallel() {
    local input_file="${TMP_DIR}/processing/domains.txt"
    local output_file="${TMP_DIR}/processing/domains.out"
    cat <<EOF >"$input_file"
example.com
foo.bar
test.org
EOF

    process_domains_parallel "$input_file" "$output_file" 2
    assert_file_exists "$output_file" "domain output generated"

    mapfile -t lines <"$output_file"
    assert_equals "3" "${#lines[@]}" "domain line count"
    assert_equals '    "example.com";' "${lines[0]}" "domain line 1 matches"
    assert_equals '    "foo.bar";' "${lines[1]}" "domain line 2 matches"
    assert_equals '    "test.org";' "${lines[2]}" "domain line 3 matches"
}

test_process_ip_stream() {
    local input_file="${TMP_DIR}/processing/router.rsc"
    local output_file="${TMP_DIR}/processing/ip.out"
    cat <<'EOF' >"$input_file"
/ip firewall address-list add address=1.1.1.0/24 list=CN
/ip firewall address-list add address=2.2.2.0/24 list=CN
mismatch line
EOF

    local ip_count
    ip_count=$(process_ip_stream "$input_file" "$output_file")

    assert_equals "2" "$ip_count" "ip count extracted"

    mapfile -t ip_lines <"$output_file"
    assert_equals "2" "${#ip_lines[@]}" "ip line count"
    assert_equals '    "1.1.1.0/24";' "${ip_lines[0]}" "ip line 1 matches"
    assert_equals '    "2.2.2.0/24";' "${ip_lines[1]}" "ip line 2 matches"
}

test_process_domains_parallel
test_process_ip_stream

cleanup_temp_root
