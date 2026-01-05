/* 
calculate_contamination.nf module

This module estimates cross-sample contamination using pileup summaries
from tumor and normal samples to improve variant calling accuracy.

GATK Version: 4.2.0.0
*/

process CALCULATE_CONTAMINATION {
    tag "${sample_id}"
    cpus 1
    memory '2.GB'
    
    input:
    tuple val(sample_id), val(tumor_id), val(normal_id), path(tumor_pileups), path(normal_pileups)

    output:
    tuple val(sample_id), val(tumor_id), val(normal_id), path("${sample_id}.contamination.table"), path("${sample_id}.segments.table")

    script:
    def is_paired = normal_pileups.name != "${sample_id}.normal-pileups.table" || normal_pileups.size() > 0
    def contamination_cmd = is_paired ?
        """
        gatk CalculateContamination \\
            -I ${tumor_pileups} \\
            -matched ${normal_pileups} \\
            -O ${sample_id}.contamination.table \\
            --tumor-segmentation ${sample_id}.segments.table
        """ :
        """
        gatk CalculateContamination \\
            -I ${tumor_pileups} \\
            -O ${sample_id}.contamination.table
        
        touch ${sample_id}.segments.table
        """
    
    """
    ${contamination_cmd}
    """
}