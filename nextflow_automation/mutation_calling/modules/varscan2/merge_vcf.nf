/* 
merge_vcf.nf module

This module merges the high confidence somatic VCF files from VarScan2, 
compresses the files, and indexes them.

GATK Version: 4.2.0.0
*/

process MERGE_VCFS {
    tag "${sample_id}"
    label 'medCpu'
    label 'lowMem'
    label 'shortTime'

    input:
    tuple val(sample_id), val(tumor_id), val(normal_id), path(snp_vcf), path(indel_vcf)
    
    output:
    tuple val(sample_id), val(tumor_id), val(normal_id), path("${sample_id}.varscan2.vcf")

    script:
    """
    # merge high confidence snp and indel vcf files
    gatk MergeVcfs \
    -I $snp_vcf \
    -I $indel_vcf \
    -O "${sample_id}.varscan2.vcf.gz" \
    -D "/references/Homo_sapiens_assembly38.dict"

    gunzip "${sample_id}.varscan2.vcf.gz"
    """
}
