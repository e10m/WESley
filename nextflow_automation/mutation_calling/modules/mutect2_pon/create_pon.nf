/* 
create_pon.nf module

This module creates a somatic panel of normals for Mutect2 to filter
out technical artifacts and germline variants.

Recommended # of normal samples: >= 40.

GATK Version: 4.2.0.0
*/

process CREATE_PON {
    tag "${params.interval_list}"
    label 'lowCpu'
    label 'highMem'
    label 'medTime'

    input:
    path(pon_db)

    output:
    path "*pon*vcf.gz"
    path "*pon*vcf.gz.tbi"

    script:
    // remove the file extension for output naming
    def output_prefix = file(params.interval_list).baseName

    """
    gatk CreateSomaticPanelOfNormals \\
    -R "/references/Homo_sapiens_assembly38.fasta" \\
    --germline-resource "/references/af-only-gnomad.hg38.vcf.gz" \\
    -V "gendb://${pon_db}" \\
    -O "${output_prefix}.pon.vcf.gz"

    gatk IndexFeatureFile -I "${output_prefix}.pon.vcf.gz"
    """
}
