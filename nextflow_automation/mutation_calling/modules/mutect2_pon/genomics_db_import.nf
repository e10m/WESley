/* 
genomics_db_import.nf module

This module creates a local GenomicsDB from VCF files for efficient
querying for creation of a Panel of Normals (PON).

Recommended # of normal samples: >= 40.

GATK Version: 4.2.0.0
*/

process MUTECT2_PON {
    tag "${params.interval_list}"
    cpus 1
    memory '4.GB'
    
    input:
    tuple val(sample_id), path(normal_vcf)

    output:
    path "pon_db/", type: 'dir'

    script:
    // collect the normal_vcfs into a list
    def normal_vcf_list = normal_vcf.collect { "-V ${it}" }.join(" ")

    """
    gatk GenomicsDBImport \\
    -R /references/Homo_sapiens_assembly38.fasta \\
    -L "/references/${params.interval_list}" \\
    --genomicsdb-workspace-path pon_db \\
    $normal_vcf_list
    """
}
