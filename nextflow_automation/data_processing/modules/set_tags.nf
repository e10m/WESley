/*
set_tags.nf module

This module takes the marked duplicate BAM files and sets tags using GATK SetNmMdAndUqTags.

GATK version: 4.2.0.0.
Python version: 3.6.10.
*/

process SET_TAGS {
    tag "$sample_id"
    label 'lowCpu'
    label 'medMem'
    label 'longTime'

    input:
    tuple val(sample_id), path(marked_bam), path(index)
    
    output:
    tuple val(sample_id), path("${sample_id}.tagged.bam"), path("${sample_id}.tagged.bai"), emit: tagged_bams

    script:
    """
    # set reference genome based on testing vs. production env
    if [ "${params.test_mode}" == "true" ] ; then
        REF_GENOME="Homo_sapiens_assembly38_chr20.fasta"
    else
        REF_GENOME="Homo_sapiens_assembly38.fasta"
    fi

    # set the metadata tags
    gatk SetNmMdAndUqTags -I $marked_bam \\
    -O "${sample_id}.tagged.bam" \\
    -R "/references/\$REF_GENOME" \\
    --CREATE_INDEX true \\
    --TMP_DIR ./
    """
}