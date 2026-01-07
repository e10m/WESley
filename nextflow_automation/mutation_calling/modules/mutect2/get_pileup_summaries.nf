/* 
get_pileup_summaries.nf module

This module generates pileup summaries for both tumor and normal samples
to enable contamination estimation in downstream processing.

GATK Version: 4.2.0.0
*/

process GET_PILEUP_SUMMARIES {
    tag "${sample_id}"
    cpus 2
    memory '3.GB'
    
    input:
    tuple val(sample_id), val(tumor_id), path(tumor_bam), path(tumor_bai), path(tumor_sbi), val(normal_id), path(normal_bam), path(normal_bai)

    output:
    tuple val(sample_id), val(tumor_id), val(normal_id), path("${sample_id}.tumor-pileups.table"), path("${sample_id}.normal-pileups.table")

    script:
    // define parameters based on testing / prod env
    def ref_genome = (params.test_mode ? "hg38_chr22.fasta" : "Homo_sapiens_assembly38.fasta")
    def variants_for_contamination = (params.test_mode ? "gnomAD_chr22.vcf.gz" : "small_exac_common_3.hg38.vcf.gz")
    def intervals = (params.test_mode ? "genome_intervals.hg38_chr22.bed" : params.interval_list)

    // ternary statement to change command run based on tumor-only vs. paired mode
    def normal_pileup_cmd = (normal_bam.name != 'NO_FILE' && normal_bam.size() > 0 ? 
        """
        gatk GetPileupSummaries \\
        -R "/references/${ref_genome}" \\
        -I ${normal_bam} \\
        --interval-set-rule INTERSECTION \\
        -L "/references/${intervals}" \\
        -V "/references/${variants_for_contamination}" \\
        -L "/references/${variants_for_contamination}" \\
        -O "${sample_id}.normal-pileups.table"
        """ : "touch ${sample_id}.normal-pileups.table")

    """
    # Get tumor pileup summaries
    gatk GetPileupSummaries \\
    -R "/references/${ref_genome}" \\
    -I ${tumor_bam} \\
    --interval-set-rule INTERSECTION \\
    -L "/references/${intervals}" \\
    -V "/references/${variants_for_contamination}" \\
    -L "/references/${variants_for_contamination}" \\
    -O "${sample_id}.tumor-pileups.table"
                
    # Get normal pileup summaries (if paired mode)
    ${normal_pileup_cmd}
    """
}