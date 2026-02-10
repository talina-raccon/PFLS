#!/usr/bin/env bash

# Check input
if [ $# -ne 1 ]; then
    echo "Usage: $0 <fasta_file>"
    exit 1
fi

FASTA="$1"

awk '
BEGIN {
    seq_count = 0
    total_len = 0
    max_len = 0
    min_len = -1
    gc_count = 0
    seq_len = 0
}
# Header line
/^>/ {
    if (seq_len > 0) {
        seq_count++
        total_len += seq_len
        if (seq_len > max_len) max_len = seq_len
        if (min_len == -1 || seq_len < min_len) min_len = seq_len
    }
    seq_len = 0
    next
}
# Sequence line
{
    line = toupper($0)
    seq_len += length(line)
    gc_count += gsub(/[GC]/, "", line)
}
END {
    # Process last sequence
    if (seq_len > 0) {
        seq_count++
        total_len += seq_len
        if (seq_len > max_len) max_len = seq_len
        if (min_len == -1 || seq_len < min_len) min_len = seq_len
    }

    avg_len = (seq_count > 0) ? total_len / seq_count : 0
    gc_content = (total_len > 0) ? (gc_count / total_len) * 100 : 0

    printf "FASTA File Statistics:\n"
    printf "----------------------\n"
    printf "Number of sequences: %d\n", seq_count
    printf "Total length of sequences: %d\n", total_len
    printf "Length of the longest sequence: %d\n", max_len
    printf "Length of the shortest sequence: %d\n", min_len
    printf "Average sequence length: %.2f\n", avg_len
    printf "GC Content (%%): %.2f\n", gc_content
}
' "$FASTA"
