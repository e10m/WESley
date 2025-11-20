/*
segment.nf

This module takes the .cnr files from CNVKit batch and segments them into
discrete copy numbers of statistical significance (p < 0.0005) using CNVKit Segment.

CNVKit version: 0.9.10.
*/

process SEGMENT {
    tag "$sample_id"
    publishDir "${params.output_dir}/cnv_calling/raw_files", mode: 'copy'
    cpus params.cpus

    input:
    tuple val(sample_id), path(cnr_file)
    
    output:
    tuple val(sample_id), path("*_noDrop_t0005.cns")

    script:
    """
    cnvkit.py segment \
    $cnr_file \
    -p ${params.cpus} \
    -t 0.0005 \
    -o "${cnr_file.simpleName}_noDrop_t0005.cns"
    """
}