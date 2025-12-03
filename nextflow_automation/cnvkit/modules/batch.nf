/*
batch.nf

This module inputs the analysis-ready BQSR BAM files and uses the CNVKit pipeline
for batch analysis.

CNVKit version: 0.9.10
*/

process BATCH {
    publishDir "${params.output_dir}/cnv_calling/raw_files", mode: 'copy', pattern: "*"
    cpus params.cpus

    input:
    path(bam_list)
    
    output:
    path("*.cnr")

    script:
    def cnn = params.legacy ? "KAPA_HyperExome_hg38_capture_targets.reference.cnn" : params.pooled_normal
    
    """
    # locate the pooled normal file
    POOLED_NORMAL=\$(find /references -name "${cnn}" -type f | head -n 1)

    # run the cnvkit batch pipeline
    cnvkit.py batch ${bam_list.join(' ')} \
    -r "\${POOLED_NORMAL}" \
    -p ${params.cpus}
    """
}