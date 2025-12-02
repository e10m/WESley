/*
apply_BQSR.nf

This module takes the recalibrated base tables and applies the
GATK BQSR algorithm, outputting the analysis-ready BAM.

GATK version: 4.2.0.0.
Python version: 3.6.10.
*/

process APPLY_BQSR {
    tag "$sample_id"
    publishDir "${params.output_dir}/preprocessing/analysis_ready_bams", mode: 'copy'
    cpus params.cpus

    input:
    tuple val(sample_id), path(tagged_bam), path(recal_data_table)
    
    output:
    tuple val(sample_id), path("${sample_id}*bam"), path("${sample_id}*bai"), emit: bqsr_bams

    script:
    """
    # run Spark version of ApplyBQSR based on production vs. testing environments
    if [ "${params.test_mode}" = "false" ]; then 
        gatk ApplyBQSRSpark -I $tagged_bam \\
            --bqsr-recal-file $recal_data_table \\
            -O "${sample_id}.BQSR.bam" \\
            --conf "spark.executor.cores=${task.cpus}"
    else
        gatk ApplyBQSR \\
            -I ${tagged_bam} \\
            --bqsr-recal-file ${recal_data_table} \\
            --create-output-bam-index true \\
            -O ${sample_id}.BQSR.bam
    fi
    """
}