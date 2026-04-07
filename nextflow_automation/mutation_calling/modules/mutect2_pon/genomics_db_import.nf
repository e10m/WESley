/*
genomics_db_import.nf module

This module creates a local GenomicsDB from VCF files for efficient
querying for creation of a Panel of Normals (PON).

Recommended # of normal samples: >= 40.

GATK Version: 4.2.0.0
*/

process GENOMICS_DB_IMPORT {
    tag "${interval_list.name}"
    label 'lowCpu'
    label 'highMem'
    label 'medTime'

    input:
    path(all_vcfs)
    path ref_fasta
    path ref_fasta_index
    path interval_list

    output:
    path "pon_db.tar"

    script:
    def vcf_args = all_vcfs.collect { "-V ${it}" }.join(" ")

    """
    gatk GenomicsDBImport \\
    -R ${ref_fasta} \\
    -L ${interval_list} \\
    --genomicsdb-workspace-path pon_db \\
    $vcf_args

    tar -cf pon_db.tar pon_db/
    """
}
