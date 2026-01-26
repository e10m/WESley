/* 
calculate_contamination.nf module

This module estimates cross-sample contamination using pileup summaries
from tumor and normal samples to improve variant calling accuracy.

GATK Version: 4.2.0.0
*/

process CALCULATE_CONTAMINATION {
    tag "${sample_id}"
    label 'medCpu'
    label 'lowMem'
    label 'shortTime'

    input:
    tuple val(sample_id), val(tumor_id), val(normal_id), path(tumor_pileups), path(normal_pileups)

    output:
    tuple val(sample_id), val(tumor_id), val(normal_id), path("${sample_id}.*.contamination.table"), path("${sample_id}*segments.table")

    script:
    // Change arguments based on paired vs. tumor-only mode
    def normal_args = (normal_pileups.size() > 0 ?
        "-matched ${normal_pileups}" : "")

    def output_name = (normal_args ? "${sample_id}.paired.contamination.table" : "${sample_id}.tumorOnly.contamination.table")
    def segment_output = (normal_args ? "${sample_id}.paired.segments.table" : "${sample_id}.tumorOnly.segments.table")
    
    """
    gatk CalculateContamination \\
        -I ${tumor_pileups} \\
        --tumor-segmentation $segment_output \\
        -O $output_name \\
        ${normal_args}
    """
}