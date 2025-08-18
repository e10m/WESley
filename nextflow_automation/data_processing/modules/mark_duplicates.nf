/*
mark_duplicates.nf module

This module takes lane-specific BAM files for each sample, merges them, 
and marks duplicates using GATK's MarkDuplicatesSpark.

The output is a single MarkDuplicate BAM for each sample.

GATK version: 4.2.0.0.
Python version: 3.6.10.
*/

process MARK_DUPES {
    tag "$sample_id"
    cpus params.cpus

    input:
    tuple val(sample_id), path(sorted_bams)
    
    output:
    tuple val(sample_id), path("${sample_id}.MarkDuplicate.bam"), path("${sample_id}.MarkDuplicate.bam.bai"), path ("${sample_id}.MarkDuplicate.bam.sbi")

    script:
    """
    mkdir -p /base_dir/tmp

    gatk MarkDuplicatesSpark \\
        ${sorted_bams.collect { "-I ${it}" }.join(" ")} \\
        -O ${sample_id}.MarkDuplicate.bam \\
        --conf "spark.executor.cores=${task.cpus}" \\
        --conf "spark.local.dir=/base_dir/tmp"
    """
}