/* 
varscan2.nf module

This module channels in metadata from the metadata sheet performs mutation calling
on the reads using the MuSE variant caller for only paired samples.

Openjdk/Java Version: 11.0.27.
VarScan Version: v2.4.3
*/

process VARSCAN2 {
    tag "${sample_id}"
    publishDir "${params.base_dir}/mutation_calls/varscan2/filtered_vcfs", mode: 'copy', pattern: "*.Somatic.hc.vcf"
    publishDir "${params.base_dir}/mutation_calls/varscan2/misc_vcfs", mode: 'copy', pattern: "*.{indel,snp}*.vcf"
    cpus 1

    input:
    tuple val(sample_id), val(tumor_id), val(normal_id), path(pileup)
    
    output:
    tuple val(sample_id), val(tumor_id), val(normal_id), path("${sample_id}.snp.Somatic.hc.vcf"), path("${sample_id}.indel.Somatic.hc.vcf")

    script:
    """
    # call variants using pileup files using VarScan 'somatic' method
    cat $pileup | java -jar /app/VarScan.v2.4.3.jar somatic \
    -mpileup \
    --min-coverage 8 \
    --min-coverage-normal 8 \
    --min-coverage-tumor 6 \
    --min-var-freq 0.1 \
    --min-freq-for-hom 0.75 \
    --p-value 0.99 \
    --somatic-p-value 0.05 \
    --strand-filter 0 \
    --output-vcf \
    --output-indel "${sample_id}.indel.vcf" \
    --output-snp "${sample_id}.snp.vcf"

    # processing initial variant calls with 'processSomatic'
    java -jar /app/VarScan.v2.4.3.jar processSomatic \
    "${sample_id}.indel.vcf" \
    --p-Value 0.01

    java -jar /app/VarScan.v2.4.3.jar processSomatic \
    "${sample_id}.snp.vcf" \
    --p-Value 0.01
    """
}
