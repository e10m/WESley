/*
segment.nf

This module takes the .cnr files from CNVKit batch and segments them into
discrete copy numbers of statistical significance (p < 0.0005) using CNVKit Segment.

CNVKit version: 0.9.10.
*/

process SEGMENT {
    publishDir "${params.base_dir}/cnv_calling/raw_files", mode: 'copy'
    cpus params.cpus

    input:
    path(cnr_file)
    
    output:
    path("*_noDrop_t0005.cns")

    script:
    """
    cnvkit.py segment \
    $cnr_file \
    -p ${params.cpus} \
    -t 0.0005 \
    --drop-low-coverage \
    -o "${cnr_file.simpleName}_noDrop_t0005.cns"
    """
}