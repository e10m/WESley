/*
apply_BQSR.nf

This module takes the recalibrated base tables and applies the
GATK BQSR algorithm, outputting the analysis-ready BAM.

GATK version: 4.2.0.0.
Python version: 3.6.10.
*/

process APPLY_BQSR {
    tag "$sample_id"
    container 'broadinstitute/gatk:4.2.0.0'
    publishDir "${params.base_dir}/preprocessing/analysis_ready_bams", mode: 'copy'
    cpus params.cpus

    input:
    tuple val(sample_id), path(tagged_bam), path(recal_data_table)
    
    output:
    tuple val(sample_id), path("${sample_id}.BQSR.bam"), path("${sample_id}.BQSR.bam.bai"), path("${sample_id}.BQSR.bam.sbi")

    script:
    """
    gatk ApplyBQSRSpark -I $tagged_bam \\
    --bqsr-recal-file $recal_data_table \\
    -O "${sample_id}.BQSR.bam" \\
    --conf "spark.executor.cores=${task.cpus}"
    """
}