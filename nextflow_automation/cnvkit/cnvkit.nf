/*
main.nf

This is the main nextflow module for orchestrating the workflow of the CNVKit phase of the pipeline.

CNVKit version: 0.9.10
*/

nextflow.enable.dsl = 2

// import modules
include { BATCH } from './modules/batch.nf'
include { SEGMENT } from './modules/segment.nf'
include { EXPORT } from './modules/export.nf'
include { MERGE } from './modules/merge.nf'

// main workflow
workflow {
    // Show help message if requested
    if (params.help) {
        help = """Usage:

        The typical command for running the pipeline is as follows:
        
        nextflow -C <CONFIG_PATH> run cnvkit.nf --base_dir <PATH> --ref_dir <PATH> --batch_number <INT> [OPTIONS]
        
        Required arguments:
        --base_dir                    Path to the base directory containing input data
        --ref_dir                     Path to the reference directory
        --batch_number                The batch number being processed (eg: 20)
        
        Optional arguments:
        --cpus                        Number of CPUs to use for processing (default: 30)
        --help                        Show this help message and exit
        
        Examples:
        
        # Basic usage with required parameters
        nextflow -C nextflow.config run cnvkit.nf --base_dir /path/to/data --ref_dir /path/to/reference --batch_number <INT>
        """
        
        // Print the help and exit
        println(help)
        exit(0)
    }

    // Parameter validation
    if (!params.base_dir) {
        error "ERROR: --base_dir parameter is required"
        exit 1
    }

    if (!params.ref_dir) {
        error "ERROR: --ref_dir parameter is required"
        exit 1
    }
    
    if (!params.batch_number) {
        error "ERROR: --batch_number parameter is required"
        exit 1
    }

    // workflow logging
    log.info """/
    ${workflow.manifest.name ?: 'Unknown'}
    ===================================================
    Command ran         : ${workflow.commandLine}
    Started on          : ${workflow.start}
    Config File used    : ${workflow.configFiles ?: 'None specified'}
    Container(s)        : ${workflow.containerEngine}:${workflow.container ?: 'None'}
    Nextflow Version    : ${workflow.manifest.nextflowVersion}
    """.stripIndent()

    ////////////////////////////
    // Start of main workflow //
    ////////////////////////////

    // channel in the bams and reference directory as individual tuples
    Channel
    .fromPath("${params.base_dir}/**/*BQSR.bam")
    .map { bam ->
        tuple(bam, params.ref_dir)
    }
    .set { bam_list }

    // group the tuples by the references folder for nested bams list  
    bams_with_ref_nested = bam_list.groupTuple(by: 1)

    // run CNVKit batch 
    cnr_list = BATCH(bams_with_ref_nested)

    cnr_list.flatten().set{cnr_files}

    // run CNVKit segment
    cns_files = SEGMENT(cnr_files)

    // convert .cns files to .seg
    seg_files = EXPORT(cns_files)

    // channel in batch number and combine with the seg_files for renaming
    batch_number = Channel.value(params.batch_number)

    seg_file_list_with_batch  = batch_number.combine(seg_files)

    seg_file_list_with_batch_nested = seg_file_list_with_batch.groupTuple()

    // merge all the .seg files
    MERGE(seg_file_list_with_batch_nested)
}
