for f in $@
do 
    echo "FASTA File_Statistic" # Header + changes 
    echo "----------------------"
    
    num_seq=0
    total_leg_seq=0
    leg_long_seq=0
    leg_sho_seq=0
    avr_seq_leg=0
    GC_cont=0

    echo "Number of sequences: $num_seq"
    echo "Total length of sequences: $total_leg_seq"
    echo "Length of the longest sequence: $leg_long_seq"
    echo "Length of the shortest sequence: $leg_sho_seq"
    echo "Average sequence length: $avr_seq_leg"
    echo "GC Content (%): $GC_cont "
    echo ""
done 