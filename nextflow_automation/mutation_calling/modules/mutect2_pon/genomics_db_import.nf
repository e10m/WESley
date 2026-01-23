/* 
genomics_db_import.nf module

This module creates a local GenomicsDB from VCF files for efficient
querying for creation of a Panel of Normals (PON).

Recommended # of normal samples: >= 40.

GATK Version: 4.2.0.0
*/

process GENOMICS_DB_IMPORT {
    tag "${params.interval_list}"
    label 'lowCpu'
    label 'highMem'
    label 'medTime'

    input:
    path(all_vcfs)

    output:
    path "pon_db/", type: 'dir'

    script:
    def vcf_args = all_vcfs.collect { "-V ${it}" }.join(" ")

    """
    gatk GenomicsDBImport \\
    -R /references/Homo_sapiens_assembly38.fasta \\
    -L "/references/${params.interval_list}" \\
    --genomicsdb-workspace-path pon_db \\
    $vcf_args
    """
}
