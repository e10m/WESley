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
    tuple val(sample_id), val(tumor_id), val(normal_id), path(unfiltered_vcf), path(orientation_model), path(contamination_table), path(segments_table)

    output:
    tuple val(sample_id), val(tumor_id), val(normal_id), path("${sample_id}.mutect2.filtered.vcf")

    script:
    def segments_arg = segments_table.name != "${sample_id}.segments.table" || segments_table.size() > 0 ?
        "--tumor-segmentation ${segments_table}" : ""
    
    """
    gatk FilterMutectCalls \\
        -V ${unfiltered_vcf} \\
        -R /references/Homo_sapiens_assembly38.fasta \\
        --contamination-table ${contamination_table} \\
        ${segments_arg} \\
        --orientation-bias-artifact-priors ${orientation_model} \\
        -O ${sample_id}.mutect2.filtered.vcf
    """
}