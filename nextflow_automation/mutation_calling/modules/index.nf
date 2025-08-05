// index.nf module
//
// This module inputs vcf files from all three variant callers, compresses them, and indexes them via bgzip/tabix
// from the samtools package.
//
// samtools version: 1.10.

process INDEX {
    tag "${sample_id}"
    cpus params.cpus

    input:
    tuple val(sample_id), val(tumor_id), val(normal_id), path(vcf_file)

    output:
    tuple val(sample_id), val(tumor_id), val(normal_id), path("*.vcf.gz"), path("*.vcf.gz.tbi")

    script:
    """
    # compress and index all variant caller vcf files
    bgzip ${vcf_file}
    tabix ${vcf_file}.gz
    """
}