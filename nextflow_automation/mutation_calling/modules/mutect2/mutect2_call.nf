/* 
mutect2_call.nf module

This module performs the initial GATK Mutect2 variant calling step.
Generates unfiltered variants and F1R2 orientation data for downstream processing.

GATK Version: 4.2.0.0
*/

process MUTECT2_CALL {
    tag "${sample_id}"
    cpus 4
    memory '4.GB'
    
    input:
    tuple val(sample_id), val(tumor_id), path(tumor_bam), path(tumor_bai), path(tumor_sbi), val(normal_id), path(normal_bam), path(normal_bai)

    output:
    tuple val(sample_id), val(tumor_id), val(normal_id), path("${sample_id}.unfiltered.vcf"), path("${sample_id}.f1r2.tar.gz")

    script:
    // change arguments based on tumor-only vs. paired calling
    def normal_args = (normal_bam.name != 'NO_FILE' && normal_bam.size() > 0 ? 
        "-I ${normal_bam} -normal ${normal_id}" : "")

    // change parameters based on testing or production environment
    def ref_genome = params.test_mode ? "hg38_chr22.fasta" : "Homo_sapiens_assembly38.fasta"
    def germline_resource = params.test_mode ? "gnomAD_chr22.vcf.gz" : "af-only-gnomad.hg38.vcf.gz"
    def interval_list = params.test_mode ? "genome_intervals.hg38_chr22.bed" : "KAPA_HyperExome_hg38_capture_targets.Mutect2.interval_list"

    """
    gatk Mutect2 \\
        -R "/references/${ref_genome}" \\
        -I ${tumor_bam} \\
        ${normal_args} \\
        --germline-resource "/references/${germline_resource}" \\
        -L "/references/${interval_list}" \\
        --f1r2-tar-gz ${sample_id}.f1r2.tar.gz \\
        -O ${sample_id}.unfiltered.vcf \\
        --genotype-germline-sites true \\
        --genotype-pon-sites true \\
        --downsampling-stride 20 \\
        --max-reads-per-alignment-start 0 \\
        --max-mnp-distance 0 \\
        --max-suspicious-reads-per-alignment-start 6 \\
        -ip 200
    """
}