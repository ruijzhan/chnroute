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

test_format_domain_lines() {
    local input_file="${TMP_DIR}/processing/domains.txt"
    local output_file="${TMP_DIR}/processing/domains.out"
    cat <<EOF >"$input_file"
example.com
foo.bar
test.org
EOF

    format_domain_lines "$input_file" "$output_file"
    assert_file_exists "$output_file" "domain output generated"

    mapfile -t lines <"$output_file"
    assert_equals "3" "${#lines[@]}" "domain line count"
    assert_equals '    "example.com";' "${lines[0]}" "domain line 1 matches"
    assert_equals '    "foo.bar";' "${lines[1]}" "domain line 2 matches"
    assert_equals '    "test.org";' "${lines[2]}" "domain line 3 matches"
}

test_format_domain_lines_empty() {
    local input_file="${TMP_DIR}/processing/empty-domains.txt"
    local output_file="${TMP_DIR}/processing/empty-domains.out"
    : >"$input_file"

    format_domain_lines "$input_file" "$output_file"
    assert_equals "0" "$(wc -l <"$output_file")" "empty list produces empty output"
}

test_extract_domains() {
    local input_file="${TMP_DIR}/processing/gfwlist.txt"
    local output_file="${TMP_DIR}/processing/extracted.txt"
    cat <<'EOF' >"$input_file"
! adblock comment
[Adblock Plus 2.0]
@@||exception.example.com^
||google.com^
|http://scheme.example.com/path
||1.2.3.4
||*.wildcard.example.net
||keep*both.example.com
||%2Fescaped.example.com
pre.fixed.example.com/path
EOF

    extract_domains "$input_file" "$output_file"
    assert_file_exists "$output_file" "extracted domain output generated"

    mapfile -t lines <"$output_file"
    assert_equals "5" "${#lines[@]}" "comments, headers, exceptions, IPv4 rules and %2F rules are dropped"
    assert_equals "google.com^" "${lines[0]}" "rule prefix stripped, trailing marker kept"
    assert_equals "scheme.example.com" "${lines[1]}" "scheme and path stripped"
    assert_equals "wildcard.example.net" "${lines[2]}" "leading wildcard label dropped"
    assert_equals "example.com" "${lines[3]}" "inner wildcard label dropped"
    assert_equals "pre.fixed.example.com" "${lines[4]}" "line without rule prefix is untouched"
}

test_extract_domains_reports_failure() {
    local output_file="${TMP_DIR}/processing/missing.out"
    local status=0

    extract_domains "${TMP_DIR}/processing/does-not-exist.txt" "$output_file" >/dev/null 2>&1 || status=$?
    assert_equals "1" "${status}" "missing input makes extract_domains fail"
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

test_merge_domain_lists() {
    local domain_file="${TMP_DIR}/processing/merge_domains.txt"
    local extra_file="${TMP_DIR}/processing/merge_extra.txt"
    local exclude_file="${TMP_DIR}/processing/merge_exclude.txt"
    cat <<EOF >"$domain_file"
keep.example.com
drop.example.com
dup.example.com
dup.example.com
EOF
    printf 'added.example.com\n\n' >"$extra_file"
    printf 'drop.example.com\n' >"$exclude_file"

    merge_domain_lists "$domain_file" "$extra_file" "$exclude_file"

    mapfile -t lines <"$domain_file"
    assert_equals "3" "${#lines[@]}" "excluded removed, extras added, deduped and sorted"
    assert_equals "added.example.com" "${lines[0]}" "extra domain merged"
    assert_equals "dup.example.com" "${lines[1]}" "duplicates collapsed"
    assert_equals "keep.example.com" "${lines[2]}" "kept domain sorted last"
}

test_format_domain_lines
test_format_domain_lines_empty
test_extract_domains
test_extract_domains_reports_failure
test_process_ip_stream
test_merge_domain_lists

cleanup_temp_root
