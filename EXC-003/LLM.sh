#!/usr/bin/env bash

# -------------------------
# Settings
# -------------------------
SOFT_PINK="#D9A6F2"  # pastel pink for stats tables
HOT_PINK="#FF1493"   # hot pink for error messages

# -------------------------
# Check input
# -------------------------
# Make sure the user provides at least one FASTA file
if [ $# -lt 1 ]; then
    echo "Usage: $0 <fasta_file1> [<fasta_file2> ...]"
    exit 1
fi

FASTA_FILES=("$@")             # store all input files in an array
REPORT="fasta_comparative_report.html"  # HTML output file

# -------------------------
# Temporary storage for summary table
# -------------------------
SUMMARY_TMP="/tmp/fasta_summary.tmp"
> "$SUMMARY_TMP"  # initialize/empty the temporary file

# -------------------------
# HTML header with CSS
# -------------------------
# Defines colors, fonts, and table styles for output
cat > "$REPORT" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Comparative FASTA Report</title>
<style>
body { font-family: Arial, sans-serif; background: #fff0f5; color: #333; }
h1 { color: $SOFT_PINK; }
h2 { color: $SOFT_PINK; margin-bottom: 0; }
.error { color: $HOT_PINK; font-weight: bold; margin-bottom: 1em; }
.error u { text-decoration: underline; }  /* underline invalid filenames */
.stats { color: $SOFT_PINK; margin-bottom: 2em; } /* individual file tables */
table { border-collapse: collapse; width: 80%; margin-bottom: 1em; }
th, td { border: 1px solid #ccc; padding: 0.5em; text-align: left; }
.summary-table { width: 100%; margin-bottom: 2em; } /* compact summary table */
</style>
</head>
<body>
<h1>Comparative FASTA Report</h1>
EOF

# -------------------------
# Loop through all input FASTA files
# -------------------------
for FASTA in "${FASTA_FILES[@]}"; do
    BASENAME=$(basename "$FASTA")  # strip directories for clean filename

    # -------------------------
    # Error Handling: Missing or Empty Files
    # -------------------------
    if [ ! -f "$FASTA" ] || [ ! -s "$FASTA" ]; then
        # HTML output: shows underlined filename and explanation
        echo "<p class='error'><u>$BASENAME</u> is missing or empty.<br>Explanation: The file does not exist or contains no data.<br>Compatible files: any valid FASTA file starting with a header line starting with &gt;.</p>" >> "$REPORT"
        continue
    fi

    # -------------------------
    # Error Handling: Not a FASTA file
    # -------------------------
    if ! grep -q '^[[:space:]]*>' "$FASTA"; then
        # HTML output: shows underlined filename and explanation
        echo "<p class='error'><u>$BASENAME</u> is not a valid FASTA file.<br>Explanation: The file does not contain sequences in FASTA format (no header lines starting with &gt; found).<br>Compatible files: text files with sequences where each sequence starts with a header line beginning with &gt; followed by sequence lines.</p>" >> "$REPORT"
        continue
    fi

    # -------------------------
    # Parse Sequence Statistics using AWK
    # -------------------------
    # AWK will generate the following for each valid FASTA:
    # 1. Individual stats table in HTML
    # 2. Save summary data to temporary file for overall summary
    awk -v fname="$BASENAME" -v summary_tmp="$SUMMARY_TMP" '
    BEGIN {
        seq_count=0; total_len=0; max_len=0; min_len=-1
        gc_count=0; at_count=0; ambiguous_count=0; seq_len=0
    }
    # Detect sequence header (new sequence starts with ">")
    /^>/ {
        if(seq_len>0){
            # Update stats for previous sequence
            seq_count++; total_len+=seq_len
            if(seq_len>max_len) max_len=seq_len
            if(min_len==-1 || seq_len<min_len) min_len=seq_len
        }
        seq_len=0; next
    }
    # Process sequence lines
    {
        line=toupper($0)         # convert to uppercase for uniform counting
        seq_len+=length(line)    # add length to current sequence
        gc_count+=gsub(/[GC]/,"",line)       # count G/C bases
        at_count+=gsub(/[AT]/,"",line)       # count A/T bases
        ambiguous_count+=gsub(/[^ATGC]/,"",line) # count ambiguous bases
    }
    END {
        # Finalize last sequence if file does not end with ">"
        if(seq_len>0){
            seq_count++; total_len+=seq_len
            if(seq_len>max_len) max_len=seq_len
            if(min_len==-1 || seq_len<min_len) min_len=seq_len
        }
        # Calculate GC content excluding ambiguous bases
        standard=gc_count+at_count
        gc_content=(standard>0)?gc_count/standard*100:0
        # Average sequence length
        avg_len=(seq_count>0)?total_len/seq_count:0

        # -------------------------
        # Save summary data for summary table
        # -------------------------
        printf "%s\t%d\t%d\t%d\t%d\t%.2f\t%.2f\t%d\n", fname, seq_count, total_len, max_len, min_len, avg_len, gc_content, ambiguous_count > summary_tmp

        # -------------------------
        # Print individual stats table for this FASTA in HTML
        # -------------------------
        printf "<div class=\"stats\"><h2>%s</h2>", fname
        printf "<table>"
        printf "<tr><th>Number of sequences</th><td>%d</td></tr>", seq_count
        printf "<tr><th>Total length of sequences</th><td>%d</td></tr>", total_len
        printf "<tr><th>Longest sequence</th><td>%d</td></tr>", max_len
        printf "<tr><th>Shortest sequence</th><td>%d</td></tr>", min_len
        printf "<tr><th>Average sequence length</th><td>%.2f</td></tr>", avg_len
        printf "<tr><th>GC content (%%)</th><td>%.2f</td></tr>", gc_content
        printf "<tr><th>Ambiguous bases</th><td>%d</td></tr>", ambiguous_count
        printf "</table></div>"
    }' "$FASTA" >> "$REPORT"
done

# -------------------------
# Generate Summary Table at the Top
# -------------------------
# Shows all valid FASTA files in one compact table
if [ -s "$SUMMARY_TMP" ]; then
    echo "<h2>Summary Table</h2>" >> "$REPORT"
    echo "<table class='summary-table'>" >> "$REPORT"
    # Table header
    echo "<tr><th>FASTA File</th><th>Sequences</th><th>Total Length</th><th>Longest</th><th>Shortest</th><th>Avg Length</th><th>GC %</th><th>Ambiguous Bases</th></tr>" >> "$REPORT"
    # Table rows from temporary summary file
    awk -F"\t" '{ printf "<tr><td>%s</td><td>%d</td><td>%d</td><td>%d</td><td>%d</td><td>%.2f</td><td>%.2f</td><td>%d</td></tr>\n",$1,$2,$3,$4,$5,$6,$7,$8 }' "$SUMMARY_TMP" >> "$REPORT"
    echo "</table>" >> "$REPORT"
fi

# -------------------------
# Finish HTML report
# -------------------------
cat >> "$REPORT" <<EOF
</body>
</html>
EOF

# -------------------------
# Clean up temporary file
# -------------------------
rm -f "$SUMMARY_TMP"

echo "Comparative report with summary table and individual stats generated: $REPORT"