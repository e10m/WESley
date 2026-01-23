/* 
fastqc.nf module 

This module takes raw FASTQ files and obtains read quality metrics
using FASTQC.

FastQC version: v0.11.9
*/

process FASTQC {
    tag "${sample_id}_${lane}"
    label 'lowCpu'
    label 'medMem'
    label 'medTime'

    input:
    tuple val(sample_id), val(lane), path(read1), path(read2), val(platform), val(seq_center), val(mouse_flag)
    
    output:
    tuple path("*.html"), path("*.zip"), emit: fastqc_files

    script:
    """
    fastqc $read1 $read2 \
    -t ${task.cpus}
    """
}