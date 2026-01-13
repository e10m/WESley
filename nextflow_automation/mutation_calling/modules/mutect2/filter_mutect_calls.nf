/* 
filter_mutect_calls.nf module

This module applies contamination and orientation bias filtering
to produce the final filtered Mutect2 variant calls.

GATK Version: 4.2.0.0
*/

process FILTER_MUTECT_CALLS {
    tag "${sample_id}"
    cpus 1
    memory '3.GB'
    
    input:
    tuple val(sample_id), val(tumor_id), val(normal_id), path(unfiltered_vcf), path(orientation_model), path(m2_stats), path(contamination_table), path(segments_table)

    output:
    tuple val(sample_id), val(tumor_id), val(normal_id), path("${sample_id}.mutect2*filtered.vcf")

    script:
    def ref_genome = (params.test_mode ? "hg38_chr22.fasta" : "Homo_sapiens_assembly38.fasta")
    def output_name = (unfiltered_vcf =~ /paired/ ? "${sample_id}.mutect2.paired.filtered.vcf" : "${sample_id}.mutect2.tumorOnly.filtered.vcf")
    
    """
    gatk FilterMutectCalls \\
        -V $unfiltered_vcf \\
        -O $output_name \\
        -R "/references/${ref_genome}" \\
        --contamination-table ${contamination_table} \\
        --tumor-segmentation ${segments_table} \\
        --orientation-bias-artifact-priors ${orientation_model} \\
        -stats $m2_stats \\
        --filtering-stats "${sample_id}.filter.stats"
    """
}