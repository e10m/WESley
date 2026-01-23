/*
merge_vcfs.nf

This module merges vcfs using GATK.

GATK version: 4.2.0.0.
*/

process MERGE_VCFS {
    tag "${sample_id}"
    label 'medCpu'
    label 'lowMem'
    label 'shortTime'

    input:
    tuple val(sample_id), path(mutect2_vcf), path(muse_vcf), path(varscan2_vcf)

    output:
    tuple val(sample_id), path("${sample_id}*vcf.gz"), path("${sample_id}*.tbi")

    script:
    """
    # merge the vcfs
    gatk MergeVcfs \
    -I $mutect2_vcf \
    -I $muse_vcf \
    -I $varscan2_vcf \
    -O "${sample_id}.consensus.merged.vcf.gz"
    """
}