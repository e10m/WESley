/*
generate_metadata.nf module

This module reads the sequencing metadata sheet and parses it using Python and Polars to output to
subsequent processes in the workflow.

Python version: 3.10.19
Polars (lts-cpu) version: 1.33.1
*/

process GENERATE_METADATA {
    tag "$sample_id"
    cpus params.cpus

    input:
    tuple val(sample_id), path(fastqs)
    
    output:
    tuple

    script:
    // TODO: define a global nextflow variable
    def mouse_flag = sample_id.contains()
    def lane = null


    // TODO: embed Python script
    // TODO: map the sample id from file name to whatever its short ID / sample name is
    """
    python make_metadata_sheet.py \
        --metadata ${params.metadata} \
        --read1 ${fastqs[0]} \
        --read2 ${fastqs[1]} \
        --output "/output_dir/$"
    """
}