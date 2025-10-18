#!/usr/bin/env bash
# shellcheck shell=bash

# Data processing helpers.

process_domains_parallel() {
    local input_file=$1
    local output_file=$2
    local thread_count=${3:-$DEFAULT_THREAD_COUNT}

    if ! [[ $thread_count =~ ^[0-9]+$ ]]; then
        log_warn "Non-numeric thread count '${thread_count}' received, falling back to ${DEFAULT_THREAD_COUNT}"
        thread_count=$DEFAULT_THREAD_COUNT
    fi

    if ! validate_file_exists "$input_file" "Domain list"; then
        return 1
    fi

    local total_lines
    total_lines=$(wc -l <"$input_file")
    if (( total_lines == 0 )); then
        : >"$output_file"
        log_warn "Domain list is empty: ${input_file}"
        return 0
    fi

    if (( thread_count < 2 )) || (( total_lines < thread_count )); then
        awk '{printf "    \"%s\";\n", $0}' "$input_file" >"$output_file"
        return 0
    fi

    local lines_per_chunk=$(( (total_lines + thread_count - 1) / thread_count ))
    local split_prefix="${TMP_DIR}/processing/domain_part_"
    split -d -l "$lines_per_chunk" "$input_file" "$split_prefix"

    shopt -s nullglob
    local parts=("${split_prefix}"*)
    if (( ${#parts[@]} == 0 )); then
        shopt -u nullglob
        awk '{printf "    \"%s\";\n", $0}' "$input_file" >"$output_file"
        return 0
    fi

    local part
    for part in "${parts[@]}"; do
        {
            awk '{printf "    \"%s\";\n", $0}' "$part" >"${part}.processed"
        } &
    done

    wait

    local processed_parts=("${split_prefix}"*.processed)
    cat "${processed_parts[@]}" >"$output_file"
    rm -f "${parts[@]}" "${processed_parts[@]}"
    shopt -u nullglob
}

process_ip_stream() {
    local input_file=$1
    local output_file=$2
    local ip_count=0

    if ! validate_file_exists "$input_file" "RouterOS script"; then
        return 1
    fi

    : >"$output_file"

    while IFS= read -r line; do
        if [[ $line =~ address=([0-9./]+) ]]; then
            printf '    "%s";\n' "${BASH_REMATCH[1]}" >>"$output_file"
            ((ip_count++))
        fi
    done <"$input_file"

    echo "$ip_count"
}
