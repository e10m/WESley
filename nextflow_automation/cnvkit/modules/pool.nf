/*
pool.nf

This module inputs the analysis-ready BQSR BAM files and uses the CNVKit pipeline
for batch analysis.

CNVKit version: 0.9.10
*/

process POOL {
    label 'highCpu'
    label 'highMem'
    label 'longTime'
    publishDir "${params.ref_dir}/${params.capture_kit}/", mode: 'copy', pattern: "*pooled*normal*cnn"

    input:
    path(normal_bam_list)
    
    output:
    path("*.cnn")

    script:
    """
    # find and initialize reference files
    ANNOTATION=\$(find /references -name "${params.annotation}" -type f | head -n 1)
    TARGETS=\$(find /references -name "${params.targets}" -type f | head -n 1)

    # run the cnvkit batch pipeline
    cnvkit.py batch \
    --normal ${normal_bam_list.join(' ')} \
    --fasta "/references/${params.ref_genome}" \
    --annotate "\${ANNOTATION}" \
    --targets "\${TARGETS}" \
    --access "/references/${params.access}" \
    --output-reference "${params.capture_kit}_${params.seq_platform}_pooled_normal.cnn" \
    -p ${params.cpus}
    """
}