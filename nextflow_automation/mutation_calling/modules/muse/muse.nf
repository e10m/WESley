/*
muse.nf module

This module channels in metadata from the metadata sheet performs mutation calling
on the reads using the MuSE variant caller for only paired samples.

MuSE Version: v1.0rc
*/

process MUSE {
    tag "${sample_id}"
    label 'lowCpu'
    label 'lowMem'
    label 'extraLongTime'

    input:
    tuple val(sample_id), val(tumor_id), path(tumor_bam), path(tumor_bai), path(tumor_sbi), val(normal_id), path(normal_bam, stageAs: "normal.bam"), path(normal_bai, stageAs: "normal.bai")
    path ref_fasta
    path ref_fasta_index
    path muse_dbsnp

    output:
    tuple val(sample_id), val(tumor_id), val(normal_id), path("${sample_id}.MuSE.sump.vcf")

    script:
    """
    # run MuSE variant caller
    # Step 1: MuSE call - unfiltered variant calling via comparison between normal/tumour bam
    MuSE call \
    -f ${ref_fasta} \
    -O "${sample_id}" \
    $tumor_bam \
    $normal_bam

    # Step 2: MuSE sump - processes / filters variants
    MuSE sump -D ${muse_dbsnp} \
    -E \
    -I "${sample_id}.MuSE.txt" \
    -O "${sample_id}.MuSE.sump.vcf"
    """
}
