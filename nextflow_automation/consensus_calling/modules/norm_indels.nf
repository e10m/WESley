/*
norm_indels.nf

This module normalizes the vcf files and deletes duplicates using
bcftools norm.

bcftools version 1.10.2
*/

process NORM_INDELS {
    tag "${sample_id}"
    
    input:
    tuple val(sample_id), path(consensus_vcf), path(consensus_index)

    output:
    tuple val(sample_id), path("${sample_id}.consensus.norm.vcf")

    script:
    """
    # merge the vcfs
    bcftools norm $consensus_vcf \
    -d none \
    -O v \
    -o "${sample_id}.consensus.norm.vcf"
    """
}