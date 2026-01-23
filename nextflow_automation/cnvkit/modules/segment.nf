/*
segment.nf

This module takes the .cnr files from CNVKit batch and segments them into
discrete copy numbers of statistical significance (p < 0.0005) using CNVKit Segment.

CNVKit version: 0.9.10.
*/

process SEGMENT {
    label 'lowCpu'
    label 'medMem'
    label 'shortTime'
    tag "$sample_id"
    publishDir "${params.output_dir}/cnv_calling/raw_files", mode: 'copy'

    input:
    tuple val(sample_id), path(cnr_file)
    
    output:
    tuple val(sample_id), path("*_noDrop_t0005.cns")

    script:
    def drop_low_coverage = params.legacy ? "--drop-low-coverage" : ""

    """
    cnvkit.py segment \
    $cnr_file \
    -p ${params.cpus} \
    -t 0.0005 \
    ${drop_low_coverage} \
    -o "${cnr_file.simpleName}_noDrop_t0005.cns"
    """
}