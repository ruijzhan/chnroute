#!/bin/bash

input_file="gfwlist_origin.txt"
output_file="invalid_domains.txt"

if [[ ! -e "$input_file" ]]; then
    echo "File not found: $input_file"
    exit 1
fi

> "$output_file"

check_domain() {
    local domain="$1"
    local output_lines=$(dig +short "$domain" | wc -l)

    [[ $output_lines -gt 0 ]]
}

while read -r domain; do
    if ! check_domain "$domain" && ! check_domain "www.$domain"; then
        echo "$domain is invalid"
        echo "$domain" >> "$output_file"
    fi
done < "$input_file"