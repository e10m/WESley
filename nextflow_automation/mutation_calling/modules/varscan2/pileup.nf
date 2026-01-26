/* 
pileup.nf module

This module takes temporary SAM files and converts them to temporary BAM files
using SAMTools version 1.10.
*/
process PILEUP {
    tag "${sample_id}"
    label 'lowCpu'
    label 'lowMem'
    label 'extraLongTime'

    input:
    tuple val(sample_id), val(tumor_id), path(tumor_bam), path(tumor_bai), path(tumor_sbi), val(normal_id), path(normal_bam, stageAs: "normal.bam"), path(normal_bai, stageAs: "normal.bai")
    
    output:
    tuple val(sample_id), val(tumor_id), val(normal_id), path("${sample_id}.pileup")

    script:
    """
    # create pileup text file
    samtools mpileup -B \
    -f "/references/Homo_sapiens_assembly38.fasta" \
    -q 1 \
    -o ${sample_id}.pileup \
    $normal_bam $tumor_bam
    """
}