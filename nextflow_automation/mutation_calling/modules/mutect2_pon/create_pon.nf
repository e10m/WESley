/*
create_pon.nf module

This module creates a somatic panel of normals for Mutect2 to filter
out technical artifacts and germline variants.

Recommended # of normal samples: >= 40.

GATK Version: 4.2.0.0
*/

process CREATE_PON {
    tag "${interval_list.name}"
    label 'lowCpu'
    label 'highMem'
    label 'medTime'

    input:
    path(pon_db_tar)
    path ref_fasta
    path ref_fasta_index
    path gnomad_vcf
    path gnomad_vcf_index
    path interval_list

    output:
    path "*pon*vcf.gz"
    path "*pon*vcf.gz.tbi"

    script:
    def output_prefix = interval_list.baseName

    """
    tar -xf ${pon_db_tar}

    gatk CreateSomaticPanelOfNormals \\
    -R ${ref_fasta} \\
    --germline-resource ${gnomad_vcf} \\
    -V "gendb://pon_db" \\
    -O "${output_prefix}.pon.vcf.gz"

    gatk IndexFeatureFile -I "${output_prefix}.pon.vcf.gz"
    """
}
