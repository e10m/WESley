#!/bin/bash

files=(*hs_metrics.txt)

for file in "${files[@]}"; do
    BASE_NAME=$(basename "$file")
    SAMPLE_ID="${BASE_NAME%%.*}"
    
    awk '
    BEGIN {
        n = split("MEAN_TARGET_COVERAGE MEDIAN_TARGET_COVERAGE PCT_TARGET_BASES_1X PCT_TARGET_BASES_2X PCT_TARGET_BASES_10X PCT_TARGET_BASES_20X PCT_TARGET_BASES_30X PCT_TARGET_BASES_40X PCT_TARGET_BASES_50X PCT_TARGET_BASES_100X PCT_TARGET_BASES_250X PCT_TARGET_BASES_500X PCT_TARGET_BASES_1000X", want, " ")
    }
    NR==7 {
        for(i=1; i<=NF; i++) cols[$i] = i
    }
    NR==8 {
        for(i=1; i<=n; i++) {
            if(want[i] in cols) {
                printf "%s: %s\n", want[i], $cols[want[i]]
            }
        }
    }' "$file" > "${SAMPLE_ID}.coverage_stats.txt"
done

echo "HS metric files parsed successfully!"