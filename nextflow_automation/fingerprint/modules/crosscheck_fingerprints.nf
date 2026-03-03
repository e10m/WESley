/*
crosscheck_fingerprints.nf module

This module takes all per-sample fingerprint VCFs and runs Picard's
CrosscheckFingerprints tool to perform an all-vs-all sample identity check.

Picard version: 3.4.0
*/

process CROSSCHECK_FINGERPRINTS {
    label 'lowCpu'
    label 'medMem'
    label 'shortTime'
    stageInMode 'symlink'

    publishDir "${params.output_dir}", mode: 'copy'

    input:
    path(vcfs)

    output:
    path("crosscheck.metrics"), emit: metrics

    script:
    def inputs = vcfs instanceof List ? vcfs.collect { "-I ${it}" }.join(" \\\n        ") : "-I ${vcfs}"
    """
    java -jar /usr/picard/picard.jar CrosscheckFingerprints \\
        ${inputs} \\
        -H /references/${params.haplotype_map} \\
        -O crosscheck.metrics \\
        --CROSSCHECK_BY SAMPLE
    """
}
