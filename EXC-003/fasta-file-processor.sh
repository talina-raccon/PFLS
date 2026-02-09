 for f in $@
do 
    echo "FASTA File Statistic" # Header 
    echo "----------------------"

    num_seq=$(grep '>' $f | wc -l | awk '{print $1}' ) 
        echo "Number of sequences: $num_seq"
   
    total_leg_seq=$(awk '!/>/{total += gsub(/[AaTtGgCc]/, "")} END {print total}' $f)
        echo "Total length of sequences: $total_leg_seq"

    length_seq_max=$(awk '/^>/ {
                                if (seqlen > max) max = seqlen
                                                        seqlen = 0
                                                        next }
                                            {seqlen += length($0)}
                                END {if (seqlen > max) max = seqlen
                                                    print max} ' $f )

    leg_long_seq=$(echo "$length_seq_max" | sort -n | tail -n 1)
        echo "Length of the longest sequence: $leg_long_seq"

lenght_seq_min=$(awk 'BEGIN {min = -1}
                        /^>/ {if (seqlen > 0) {if (min < 0 || seqlen < min) 
                                    min = seqlen}
                                    seqlen = 0
                                    next}
                                {seqlen += length($0)}
                     END {if (seqlen > 0 && (min < 0 || seqlen < min))
                                {min = seqlen} print min} ' $f)

leg_sho_seq=$(echo "$lenght_seq_min")
        echo "Length of the shortest sequence: $leg_sho_seq"
#Here needs to be a If-Condition so it runs even without a good FASTA file
        echo "Average sequence length: $(echo " scale=3; $total_leg_seq/$num_seq" | bc) "

    GC_cont=$(awk '!/>/{gc_count += gsub(/[GgCc]/, "")} END {print gc_count}' $f)
         echo "GC Content (%): $(echo "scale=3; $GC_cont *100 / $total_leg_seq" | bc) "
         
        echo ""
done 

