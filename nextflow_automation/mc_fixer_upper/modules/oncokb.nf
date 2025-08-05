/* 
oncokb.nf

This module provides clinically relevant annotations to the variant calling MAF files
using Oncokb.

Oncokb Version: 3.0.0.
*/

process ONCOKB {
    tag "${sample_id}"
    publishDir "${params.base_dir}/mutation_calls/oncokb_annotation", mode: 'copy', pattern: "*.maf"
    
    input:
    tuple val(sample_id), path(nonsyno_maf)

    output:
    tuple val(sample_id), path("*vep.nonsynonymous.oncokb.maf")

    script:
    """
    # save the base name to change parameters based on variant caller
    BASE_NAME=\$(basename "${nonsyno_maf}")

    if [[ "\$BASE_NAME" == *"mutect2.tumorOnly"* ]]; then
        OUTPUT_NAME="${sample_id}.mutect2.tumorOnly.vep.nonsynonymous.oncokb.maf"
    elif [[ "\$BASE_NAME" == *"mutect2.paired"* ]]; then
        OUTPUT_NAME="${sample_id}.mutect2.paired.vep.nonsynonymous.oncokb.maf"
    elif [[ "\$BASE_NAME" == *"MuSE"* ]]; then
        OUTPUT_NAME="${sample_id}.MuSE.vep.nonsynonymous.oncokb.maf"
    elif [[ "\$BASE_NAME" == *"varscan2"* ]]; then
        OUTPUT_NAME="${sample_id}.varscan2.vep.nonsynonymous.oncokb.maf"
    fi
    
    # annotate via oncokb
    python /app/MafAnnotator.py \
    -i $nonsyno_maf \
    -o \$OUTPUT_NAME \
    -r GRCh38 \
    -b "\$ONCOKB_TOKEN" \
    -t BRAIN
    """
}