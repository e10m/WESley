#!/bin/bash

# put all bam files in wd into an array
bam_files=(*.bam)

# quick for loop to run gatk CollectHsMetrics
for file in "${bam_files[@]}"; do
    # get base name of file
    BASE_NAME=$(basename "$file")

    # get sample id
    SAMPLE_ID="${BASE_NAME%%.*}"

    # run gatk command using Docker container
    gatk CollectHsMetrics \
    I=$file \
    O="/data/${SAMPLE_ID}.hs_metrics.txt" \
    R=/references/Homo_sapiens_assembly38.fasta \
    BAIT_INTERVALS=/references/KAPA_bait.interval_list \
    TARGET_INTERVALS=/references/KAPA_target.interval_list
done