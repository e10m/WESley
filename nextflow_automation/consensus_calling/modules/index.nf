/*
index.nf

This module compresses and indexes the sorted vcfs.

samtools version: 1.10.
*/

process INDEX {
    tag "${sample_id}"
    
    input:
    tuple val(sample_id), path(mutect2_vcf), path(muse_vcf), path(varscan2_vcf)

    output:
    tuple val(sample_id), path("*mutect2*.vcf.gz"), path("*mutect2*.vcf.gz.tbi"), path("*MuSE*.vcf.gz"), path("*MuSE*.vcf.gz.tbi"), path("*varscan2*.vcf.gz"), path("*varscan2*.vcf.gz.tbi")

    script:
    """
    # compress vcfs
    bgzip $mutect2_vcf
    bgzip $muse_vcf
    bgzip $varscan2_vcf

    # index compressed vcfs
    tabix "${mutect2_vcf}.gz"
    tabix "${muse_vcf}.gz"
    tabix "${varscan2_vcf}.gz"
    """

}