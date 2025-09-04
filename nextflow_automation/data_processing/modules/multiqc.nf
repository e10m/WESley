/* 
multiqc.nf module

This module aggregates all the QC metrics produced by the WESley
pipeline and outputs a summary of results

MultiQC version: v1.30.
*/

process MULTIQC {
    publishDir "${params.base_dir}/QC", mode: 'copy'

    input:
    val ready
    
    output:
    path("multiqc_report.html")
    path("multiqc_data/*")

    script:
    """
    multiqc ${workflow.workDir}
    """
}