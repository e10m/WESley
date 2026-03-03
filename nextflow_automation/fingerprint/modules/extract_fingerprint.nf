/*
extract_fingerprint.nf module

This module takes an analysis-ready BAM file and runs Picard's
ExtractFingerprint tool to produce a per-sample fingerprint VCF.

Picard version: 3.4.0
*/

process EXTRACT_FINGERPRINT {
    tag "${sample_id}"
    label 'lowCpu'
    label 'medMem'
    label 'shortTime'
    stageInMode 'copy'    // copy BAMs from bam_dir into work dir

    publishDir "${params.output_dir}/fingerprints", mode: 'copy'

    input:
    tuple val(sample_id), path(bam), path(bai)

    output:
    tuple val(sample_id), path("${sample_id}.fingerprint.vcf"), emit: vcf

    script:
    """
    java -jar /usr/picard/picard.jar ExtractFingerprint \\
        -I ${bam} \\
        -H /references/${params.haplotype_map} \\
        -O ${sample_id}.fingerprint.vcf
    """
}
