/*
export.nf

This module takes in the segment (.cns) files containing the copy number segments of statistical significance and 
exports them into the .seg file format using CNVKit export.

CNVKit version: 0.9.10.
*/

process EXPORT {
    tag "$sample_id"
    publishDir "${params.output_dir}/cnv_calling/segmentation", mode: 'copy'
    cpus 1

    input:
    tuple val(sample_id), path(cns_file)
    
    output:
    path("*.seg")

    script:
    """
    cnvkit.py export seg \
    $cns_file \
    -o "${cns_file.simpleName}.seg"
    """
}