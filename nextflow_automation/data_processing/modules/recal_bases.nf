/*
recal_bases.nf

This module takes the tagged BAM files and recalibrates base
quality scores using GATK BaseRecalibratorSpark

GATK version: 4.2.0.0.
Python version: 3.6.10.
*/

process RECAL_BASES {
    tag "$sample_id"
    cpus params.cpus

    input:
    tuple val(sample_id), path(tagged_bam), path(index)
    
    output:
    tuple val(sample_id), path(tagged_bam), path("${sample_id}.recal_data.table")

    script:
    """
    gatk BaseRecalibratorSpark -I $tagged_bam \\
    -R "/references/Homo_sapiens_assembly38.fasta" \\
    --known-sites "/references/Homo_sapiens_assembly38.dbsnp138.vcf.gz" \\
    --known-sites "/references/Homo_sapiens_assembly38.known_indels.vcf.gz" \\
    -O "${sample_id}.recal_data.table" \\
    --conf "spark.executor.cores=${task.cpus}"
    """
}