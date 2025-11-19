/*
batch.nf

This module inputs the analysis-ready BQSR BAM files and uses the CNVKit pipeline
for batch analysis.

CNVKit version: 0.9.10
*/

process BATCH {
    publishDir "${params.base_dir}/cnv_calling/raw_files", mode: 'copy', pattern: "*{.cnr, .cns, .call.cns}"
    cpus params.cpus

    input:
    path(bam_list)
    
    output:
    path("*.cnr")

    script:
    """
    cnvkit.py batch ${bam_list.join(' ')} \
    -r "/references/${params.pooled_normal}" \
    -p ${params.cpus}
    """
}