/* 
calc_coverage.nf module 

This module takes analysis-ready BAM files and calculates
coverage statistics via Picard's CollectHsMetrics tool.

GATK Version: 4.2.0.0.
*/

process CALC_COVERAGE {
    tag "${sample_id}"
    label 'lowCpu'
    label 'medMem'
    label 'medTime'

    input:
    tuple val(sample_id), path(bam), path(bai)
    
    output:
    path("${sample_id}.hs_metrics.txt"), emit: stats

    script:
    """
    gatk CollectHsMetrics \
    I=${bam} \
    O="${sample_id}.hs_metrics.txt" \
    R="/references/Homo_sapiens_assembly38.fasta" \
    BAIT_INTERVALS=/references/KAPA_bait.interval_list \
    TARGET_INTERVALS=/references/KAPA_target.interval_list
    """
}