#!/usr/bin/env bash
# shellcheck shell=bash

# Data processing helpers.

# Turns a plain domain list into RouterOS :global string array entries.
format_domain_lines() {
    local input_file=$1
    local output_file=$2

    if ! validate_file_exists "$input_file" "Domain list"; then
        return 1
    fi

    awk '{printf "    \"%s\";\n", $0}' "$input_file" >"$output_file"

    if [[ ! -s "$output_file" ]]; then
        log_warn "Domain list is empty: ${input_file}"
    fi
}

# Extracts plain domains from a GFWList-formatted file.
#
# One awk pass instead of grep|sed|sed|grep|sed; every stage of the original
# pipeline is transcribed verbatim, so the output is byte-identical:
#   - ignored: adblock comments ("!"), header lines ("["), rule exceptions
#     ("@@") and any line carrying an IPv4 literal
#   - head:    drop the leading "||" / "|"/ "http(s)://" rule prefix
#   - tail:    drop everything from the first "/" or "%2F" (URL paths)
#   - keep:    only lines carrying a domain-shaped token
#   - wildcards: rewrite "*.foo.com" / "sub.*.foo.com" to "foo.com"
extract_domains() {
    local input_file=$1
    local output_file=$2

    # wildcards() mirrors the final sed stage
    #   s#^(([a-zA-Z0-9]*\*[-a-zA-Z0-9]*)?(\.))?([a-zA-Z0-9][-a-zA-Z0-9]*
    #   (\.[a-zA-Z0-9][-a-zA-Z0-9]*)+)(\*[a-zA-Z0-9]*)?#\4#g
    # without backreferences (not supported by awk replacements in every
    # implementation), locating the leading wildcard label and the trailing
    # wildcard label around the domain group instead. A line the pattern does
    # not match is emitted unchanged, exactly as sed did.
    if ! awk '
        function wildcards(line, prefix, domain, rest) {
            prefix = 0
            if (match(line, /^([a-zA-Z0-9]*\*[-a-zA-Z0-9]*)?\./))
                prefix = RLENGTH
            else if (substr(line, 1, 1) == ".")
                prefix = 1

            if (!match(substr(line, prefix + 1), /^[a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)+/))
                return line

            domain = substr(line, prefix + 1, RLENGTH)
            rest = substr(line, prefix + 1 + RLENGTH)
            sub(/^\*[a-zA-Z0-9]*/, "", rest)
            return domain rest
        }
        {
            if (/^!/ || /\[/ || /^@@/ || /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/) next
            sub(/^(\|\|?)?(https?:\/\/)?/, "")
            sub(/\/.*$/, "")
            sub(/%2F.*$/, "")
            if ($0 !~ /[a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)+/) next
            print wildcards($0)
        }
    ' "$input_file" >"$output_file"; then
        log_error "Failed to extract domains from ${input_file}"
        return 1
    fi
}

# Applies the exclude list, the extra-domain list and the final unique sort to
# an already extracted domain file, in place.
merge_domain_lists() {
    local domain_file=$1
    local extra_file=$2
    local exclude_file=$3

    if [[ -n "$exclude_file" ]]; then
        log_info "Applying exclude list ${exclude_file}"
        local filtered_file="${domain_file}.filtered"
        if ! grep -vF -f "$exclude_file" "$domain_file" >"$filtered_file"; then
            log_warn "All domains excluded by ${exclude_file}"
        fi
        mv "$filtered_file" "$domain_file"
    fi

    if [[ -n "$extra_file" ]]; then
        log_info "Appending extra domains from ${extra_file}"
        grep -v '^[[:space:]]*$' "$extra_file" >>"$domain_file" || true
    fi

    LC_ALL=POSIX sort -u "$domain_file" -o "$domain_file"
}

# Emits the "    \"1.2.3.0/24\";" entries of a RouterOS script and reports how
# many were written.
#
# Regex-equivalence contract with the original `address=([0-9./]+)` bash
# partial match:
#   - index() finds the first "address=" (mirrors partial match).
#   - match(/^[0-9.\/]+/) captures the greedy [0-9./]+ prefix only,
#     skipping lines whose first post-"address=" byte is not in the
#     class (e.g. "address=NOT_AN_IP" is dropped).
# POSIX two-arg match() is used instead of gawk's three-arg form so
# this also runs under BSD awk on macOS.
process_ip_stream() {
    local input_file=$1
    local output_file=$2

    if ! validate_file_exists "$input_file" "RouterOS script"; then
        return 1
    fi

    awk '
        {
            idx = index($0, "address=")
            if (idx == 0) next
            rest = substr($0, idx + 8)
            if (match(rest, /^[0-9.\/]+/)) {
                printf "    \"%s\";\n", substr(rest, 1, RLENGTH)
            }
        }
    ' "$input_file" >"$output_file"

    # The count file awk used to write is redundant: every entry is one
    # line. Arithmetic normalization strips the leading spaces BSD wc adds.
    echo $(( $(wc -l <"$output_file") ))
}
