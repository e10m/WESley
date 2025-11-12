/* 
multiqc.nf module

This module aggregates all the QC metrics produced by the WESley
pipeline and outputs a summary of results

MultiQC version: v1.30.
*/

process MULTIQC {
    publishDir "${params.base_dir}/QC-${params.batch_name}", mode: 'copy'
    containerOptions "-v ${workflow.workDir}:/work"

    input:
    val "ready"

    output:
    path("multiqc_report.html"), emit: multiqc_html
    path("multiqc*/*"), emit: multiqc_files

    script:
    """
    multiqc /work
    """
}