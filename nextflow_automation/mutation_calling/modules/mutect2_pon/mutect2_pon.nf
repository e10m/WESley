/*
mutect2_pon.nf module

This module performs the initial GATK Mutect2 variant calling step
for creating a Panel of Normals (PON) from normal samples only.

Recommended # of normal samples: >= 40.

GATK Version: 4.2.0.0
*/

process MUTECT2_PON {
    tag "${sample_id}"
    label 'lowCpu'
    label 'medMem'
    label 'extraLongTime'

    input:
    tuple val(sample_id), path(normal_bam), path(normal_bai)
    path ref_fasta
    path ref_fasta_index

    output:
    path("*vcf*")

    script:
    """
    gatk Mutect2 \\
        -R ${ref_fasta} \\
        -I $normal_bam \\
        --max-mnp-distance 0 \\
        -O "${sample_id}.vcf.gz"
    """
}
