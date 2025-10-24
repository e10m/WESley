/* 
oncokb.nf

This module provides clinically relevant annotations to the variant calling MAF files
using Oncokb.

Oncokb Version: 3.0.0.
*/

process ONCOKB {
    tag "${sample_id}"
    publishDir "${params.base_dir}/mutation_calls/consensus/oncokb_annotation", mode: 'copy', pattern: "*vep.nonsynonymous.oncokb.maf"
    secret 'ONCOKB_API_KEY'
    
    input:
    tuple val(sample_id), path(nonsyno_maf)

    output:
    tuple val(sample_id), path("*vep.nonsynonymous.oncokb.maf")

    script:
    """
    # annotate via oncokb
    python /app/MafAnnotator.py \
    -i $nonsyno_maf \
    -o "${sample_id}.consensus.vep.nonsynonymous.oncokb.maf" \
    -r GRCh38 \
    -b "\$ONCOKB_API_KEY" \
    -t BRAIN
    """
}