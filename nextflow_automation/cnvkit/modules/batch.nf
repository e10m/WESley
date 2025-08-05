/*
batch.nf

This module inputs the analysis-ready BQSR BAM files and uses the CNVKit pipeline
for batch analysis.

CNVKit version: 0.9.10
*/

process BATCH {
    publishDir "${params.base_dir}/cnv_calling/raw_files", mode: 'copy', pattern: "*.cnr"
    publishDir "${params.base_dir}/cnv_calling/misc_files", mode: 'copy', pattern: "*{.cns,.call.cns}"
    cpus params.cpus

    input:
    tuple path(bam_list), path(ref_dir)
    
    output:
    path("*.cnr")

    script:
    """
    cnvkit.py batch ${bam_list.join(' ')} \
    -r "${ref_dir}/KAPA_HyperExome_hg38_capture_targets.reference.cnn" \
    -p ${params.cpus}
    """
}