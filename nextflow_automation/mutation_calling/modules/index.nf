// index.nf module
//
// This module inputs vcf files from all three variant callers, compresses them, and indexes them via bgzip/tabix
// from the samtools package.
//
// samtools version: 1.10.

process INDEX {
    tag "${sample_id}"
    publishDir "${params.base_dir}/mutation_calls/mutect2/raw-vcfs", mode: 'copy', pattern: "*mutect2*vcf*"
    publishDir "${params.base_dir}/mutation_calls/varscan2/raw-vcfs", mode: 'copy', pattern: "*varscan2*vcf*"
    publishDir "${params.base_dir}/mutation_calls/MuSE/raw-vcfs", mode: 'copy', pattern: "*MuSE*vcf*"
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