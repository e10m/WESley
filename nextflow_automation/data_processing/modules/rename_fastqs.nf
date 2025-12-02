/*
generate_metadata.nf module

This module reads the sequencing metadata sheet and parses it using Python and Polars to output to
subsequent processes in the workflow.

Python version: 3.10.19
Polars (lts-cpu) version: 1.33.1
*/

process RENAME_FASTQS {
    tag "$sample_id"
    cpus params.cpus

    input:
    tuple val(sample_id), val(lane), path(fastq_1), path(fastq_2), val(platform), val(seq_center), val(mouse_flag)
    
    output:
    tuple val(sample_id), val(lane), path("*.{fastq}"), path(fastq_2), val(platform), val(seq_center), val(mouse_flag)

    script:
    """
    # TODO: embed the python script to read in metadata sheet, rename sample_id accordingly
    # TODO: import the system command to run bash command and rename the FASTQs
    python metamaker*** 
    """
}