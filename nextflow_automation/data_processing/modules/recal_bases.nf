/*
recal_bases.nf

This module takes the tagged BAM files and recalibrates base
quality scores using GATK BaseRecalibratorSpark

GATK version: 4.2.0.0.
Python version: 3.6.10.
*/

process RECAL_BASES {
    tag "$sample_id"
    label 'highCpu'
    label 'highMem'
    label 'shortTime'

    input:
    tuple val(sample_id), path(tagged_bam), path(index)
    
    output:
    tuple val(sample_id), path(tagged_bam), path("${sample_id}.recal_data.table"), emit: recal_table

    script:
    """
    # run Spark version of BaseRecalibrator based on production vs. testing environments
        if [ "${params.test_mode}" = "false" ]; then 
            gatk BaseRecalibratorSpark -I $tagged_bam \\
                -R "/references/Homo_sapiens_assembly38.fasta" \\
                --known-sites "/references/Homo_sapiens_assembly38.dbsnp138.vcf.gz" \\
                --known-sites "/references/Homo_sapiens_assembly38.known_indels.vcf.gz" \\
                -O "${sample_id}.recal_data.table" \\
                --conf "spark.executor.cores=${task.cpus}"
        else
            gatk BaseRecalibrator \\
            -I "${tagged_bam}" \\
            -R "/references/Homo_sapiens_assembly38_chr20.fasta" \\
            -O ${sample_id}.recal_data.table \\
            --known-sites "/references/dbsnp_146_hg38_chr20_tso-only.vcf.gz" \\
            --known-sites "/references/Mills_and_1000G_gold_standard_indels_hg38_chr20.vcf.gz"
        fi
    """
}