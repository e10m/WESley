/*
INTERSECT.nf module

This module generates consensus vcfs using bcftools isec by 
creating intersections, unions and complements of VCF files.

bcftools version: 1.10.2.
*/

process INTERSECT {
    tag "${sample_id}"
    label 'lowCpu'
    label 'lowMem'
    label 'medTime'

    input:
    tuple val(sample_id), path(mutect2_vcf), path(mutect2_index), path(muse_vcf), path(muse_index), path(varscan2_vcf), path(varscan2_index)

    output:
    tuple val(sample_id), path("**/0000.vcf"), path("**/0001.vcf"), path("**/0002.vcf")

    script:
    """
    # create consensus vcfs
    bcftools isec -n +2 -p \
    $sample_id \
    $mutect2_vcf \
    $muse_vcf \
    $varscan2_vcf
    """
}