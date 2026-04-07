/*
get_pileup_summaries.nf module

This module generates pileup summaries for both tumor and normal samples
to enable contamination estimation in downstream processing.

GATK Version: 4.2.0.0
*/

process GET_PILEUP_SUMMARIES {
    tag "${sample_id}"
    label 'lowCpu'
    label 'lowMem'
    label 'medTime'

    input:
    tuple val(sample_id), val(tumor_id), path(tumor_bam), path(tumor_bai), path(tumor_sbi), val(normal_id), path(normal_bam), path(normal_bai)
    path ref_fasta
    path ref_fasta_index
    path ref_dict
    path contamination_vcf
    path contamination_vcf_index
    path interval_list

    output:
    tuple val(sample_id), val(tumor_id), val(normal_id), path("${sample_id}.tumor-pileups.table"), path("${sample_id}.normal-pileups.table")

    script:
    def normal_pileup_cmd = (normal_bam.name != 'NO_FILE' && normal_bam.size() > 0 ?
        """
        gatk GetPileupSummaries \\
        -R ${ref_fasta} \\
        -I ${normal_bam} \\
        --interval-set-rule INTERSECTION \\
        -L ${interval_list} \\
        -V ${contamination_vcf} \\
        -L ${contamination_vcf} \\
        -O "${sample_id}.normal-pileups.table"
        """ : "touch ${sample_id}.normal-pileups.table")

    """
    # Get tumor pileup summaries
    gatk GetPileupSummaries \\
    -R ${ref_fasta} \\
    -I ${tumor_bam} \\
    --interval-set-rule INTERSECTION \\
    -L ${interval_list} \\
    -V ${contamination_vcf} \\
    -L ${contamination_vcf} \\
    -O "${sample_id}.tumor-pileups.table"

    # Get normal pileup summaries (if paired mode)
    ${normal_pileup_cmd}
    """
}
