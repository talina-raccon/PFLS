#!/usr/bin/env bash

COMBINED_DIR="COMBINED-DATA"
RAW_DIR="RAW-DATA"
TRANSLATION_FILE="$RAW_DIR/sample-translation.txt"

# Step 1: Create COMBINED-DATA if needed
if [ -d "$COMBINED_DIR" ]; then
    echo "Directory '$COMBINED_DIR' already exists."
else
    echo "Creating directory '$COMBINED_DIR'..."
    mkdir "$COMBINED_DIR"
    echo "Directory '$COMBINED_DIR' created."
fi

# Step 2a: Clean COMBINED-DATA if it contains files
if [ "$(ls -A "$COMBINED_DIR")" ]; then
    echo "COMBINED-DATA is not empty. Removing existing files..."
    rm -f "$COMBINED_DIR"/*
fi

# Step 2b: Process FASTA files
for sample_dir in "$RAW_DIR"/*; do
    # Only proceed if it's a directory
    if [ ! -d "$sample_dir" ]; then
        continue
    fi

    sample_name=$(basename "$sample_dir")
    fasta_file="$sample_dir/bins/bin-unbinned.fasta"

    echo "Processing sample: '$sample_name'"

    # Check if FASTA file exists
    if [ ! -f "$fasta_file" ]; then
        echo "  Missing FASTA file at: $fasta_file — skipping."
        continue
    fi

    # Get culture name from translation file (column 2, skip header)
    culture_name=$(awk -v sample="$sample_name" 'NR>1 && $1 == sample {print $2}' "$TRANSLATION_FILE")

    # Check if culture name was found
    if [ -z "$culture_name" ]; then
        echo "  Missing culture name for '$sample_name' in translation file — skipping."
        continue
    fi

    # Copy the file with new name
    output_file="$COMBINED_DIR/${culture_name}_UNBINNED.fa"
    
    awk -v prefix="$culture_name" '
    /^>/ {
        sub(/^>/, ">" prefix "|")
    }
    { print }
' "$fasta_file" > "$output_file"


    echo "  Copied -> $output_file"
done

# -------------------------
# Step 3: Copy MAGs and BINs using CheckM results
# -------------------------

declare -A MAG_COUNT
declare -A BIN_COUNT

for sample_dir in "$RAW_DIR"/*; do
    if [ ! -d "$sample_dir" ]; then
        continue
    fi

    sample_name=$(basename "$sample_dir")
    bins_dir="$sample_dir/bins"
    checkm_file="$sample_dir/checkm.txt"

    echo "Processing bins for sample: $sample_name"

    # Get culture name (column 2, skip header)
    culture_name=$(awk -v sample="$sample_name" 'NR>1 && $1 == sample {print $2}' "$TRANSLATION_FILE")

    if [ -z "$culture_name" ]; then
        echo "  No culture name found — skipping sample."
        continue
    fi

    if [ ! -d "$bins_dir" ]; then
        echo "  No bins directory — skipping."
        continue
    fi

    if [ ! -f "$checkm_file" ]; then
        echo "  No checkm.txt — skipping."
        continue
    fi

    for fasta_file in "$bins_dir"/*.fasta; do
        fasta_name=$(basename "$fasta_file")

        # Skip unbinned fasta
        if [ "$fasta_name" = "bin-unbinned.fasta" ]; then
            continue
        fi

        fasta_bin_id="${fasta_name%.fasta}"

        # Extract completeness and contamination by suffix match
        read completeness contamination < <(
    awk -v id="$fasta_bin_id" '
        $1 ~ id"$" {
            print $(NF-2), $(NF-1)
            exit
        }
    ' "$checkm_file"
    )


        if [ -z "$completeness" ]; then
            echo "  No CheckM entry for $fasta_bin_id — skipping."
            continue
        fi

        # Determine MAG or BIN
        if (( $(echo "$completeness >= 50" | bc -l) )) && \
           (( $(echo "$contamination <= 5" | bc -l) )); then
            type="MAG"
            MAG_COUNT["$culture_name"]=$((MAG_COUNT["$culture_name"] + 1))
            num=$(printf "%03d" "${MAG_COUNT["$culture_name"]}")
        else
            type="BIN"
            BIN_COUNT["$culture_name"]=$((BIN_COUNT["$culture_name"] + 1))
            num=$(printf "%03d" "${BIN_COUNT["$culture_name"]}")
        fi

        output_file="$COMBINED_DIR/${culture_name}_${type}_${num}.fa"
        
        awk -v prefix="$culture_name" '
    /^>/ {
        sub(/^>/, ">" prefix "|")
    }
    { print }
' "$fasta_file" > "$output_file"


        echo "  Copied $fasta_name → $(basename "$output_file")"
    done
done

# -------------------------
# Step 4: Copy checkm.txt and GTDB files
# -------------------------
for sample_dir in "$RAW_DIR"/*; do
    [ -d "$sample_dir" ] || continue

    sample_name=$(basename "$sample_dir")

    # Get culture name
    culture_name=$(awk -v sample="$sample_name" 'NR>1 && $1 == sample {print $2}' "$TRANSLATION_FILE")

    if [ -z "$culture_name" ]; then
        echo "No culture name found for $sample_name — skipping metadata copy."
        continue
    fi

    checkm_file="$sample_dir/checkm.txt"
    gtdb_file="$sample_dir/gtdb.gtdbtk.tax"

    # Copy checkm.txt if it exists
    if [ -f "$checkm_file" ]; then
        cp "$checkm_file" "$COMBINED_DIR/${culture_name}-CHECKM.txt"
        echo "Copied checkm.txt → ${culture_name}-CHECKM.txt"
    else
        echo "No checkm.txt found for $sample_name — skipping."
    fi

    # Copy gtdb.gtdbtk.tax if it exists
    if [ -f "$gtdb_file" ]; then
        cp "$gtdb_file" "$COMBINED_DIR/${culture_name}-GTDB-TAX.txt"
        echo "Copied gtdb.gtdbtk.tax → ${culture_name}-GTDB-TAX.txt"
    else
        echo "No gtdb.gtdbtk.tax found for $sample_name — skipping."
    fi
done

# -------------------------
# Final summary: custom ordered listing
# -------------------------
echo
echo "All files in COMBINED-DATA (custom sorted):"

for culture in $(ls "$COMBINED_DIR" | sed -E 's/^([^-]+).*/\1/' | sort -u); do
    # 1. CHECKM file
    [ -f "$COMBINED_DIR/${culture}-CHECKM.txt" ] && echo "${culture}-CHECKM.txt"

    # 2. GTDB file
    [ -f "$COMBINED_DIR/${culture}-GTDB-TAX.txt" ] && echo "${culture}-GTDB-TAX.txt"

    # 3. BIN files
    ls "$COMBINED_DIR" | grep "^${culture}_BIN_" | sort -V | while read f; do
        echo "$f"
    done

    # 4. MAG files
    ls "$COMBINED_DIR" | grep "^${culture}_MAG_" | sort -V | while read f; do
        echo "$f"
    done

    # 5. UNBINNED file
    [ -f "$COMBINED_DIR/${culture}_UNBINNED.fa" ] && echo "${culture}_UNBINNED.fa"
done

echo
echo "Total files: $(ls -1 "$COMBINED_DIR" | wc -l)"
