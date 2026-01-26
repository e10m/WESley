/* 
learn_read_orientation.nf module

This module learns read orientation bias patterns from F1R2 data
to enable artifact filtering in downstream variant processing.

GATK Version: 4.2.0.0
*/

process LEARN_READ_ORIENTATION {
    tag "${sample_id}"
    label 'lowCpu'
    label 'lowMem'
    label 'shortTime'

    input:
    tuple val(sample_id), val(tumor_id), val(normal_id), path(unfiltered_vcf), path(f1r2_tar), path(m2_stats)

    output:
    tuple val(sample_id), val(tumor_id), val(normal_id), path(unfiltered_vcf), path("${sample_id}.read-orientation-model.tar.gz"), path(m2_stats)

    script:
    """
    gatk LearnReadOrientationModel \\
        -I "${f1r2_tar}" \\
        -O "${sample_id}.read-orientation-model.tar.gz"
    """
}