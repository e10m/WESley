/* 
trim_adapters module 

This module takes FASTQ files and trims them for pre-processing using
TrimGalore version 0.6.6.

TrimGalore version: 0.6.6
*/

process TRIM {
    tag "${sample_id}_${lane}"
    cpus 8

    input:
    tuple val(sample_id), val(lane), path(read1), path(read2), val(platform), val(seq_center), val(mouse_flag)
    
    output:
    tuple val(sample_id), val(lane), path("${sample_id}_${lane}_val_1.fq.gz"), path("${sample_id}_${lane}_val_2.fq.gz"), val(platform), val(seq_center), val(mouse_flag)

    script:
    """
    echo "Trimming $sample_id on $lane..."
    
    trim_galore --illumina \
    --cores 8 \
    --paired $read1 $read2 \
    --basename "${sample_id}_${lane}"
    """
}