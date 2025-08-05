/*
set_tags.nf module

This module takes the marked duplicate BAM files and sets tags using GATK SetNmMdAndUqTags.

GATK version: 4.2.0.0.
Python version: 3.6.10.
*/

process SET_TAGS {
    tag "$sample_id"
    container 'broadinstitute/gatk:4.2.0.0'
    executor 'local'
    cpus 1
    maxForks 30

    input:
    tuple val(sample_id), path(marked_bam), path(index), path(sliced_index)
    
    output:
    tuple val(sample_id), path("${sample_id}.tagged.bam"), path("${sample_id}.tagged.bai")

    script:
    """
    gatk SetNmMdAndUqTags -I $marked_bam \\
    -O "${sample_id}.tagged.bam" \\
    -R "/references/Homo_sapiens_assembly38.fasta" \\
    --CREATE_INDEX true \\
    --TMP_DIR ./
    """
}