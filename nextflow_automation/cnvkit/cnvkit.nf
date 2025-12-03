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
workflow CNV_CALLING {
    // Show help message if requested
    if (params.help) {
        help = """Usage:

        The typical command for running the pipeline is as follows:
        
        nextflow -C <CONFIG_PATH> run cnvkit.nf --base_dir <PATH> --ref_dir <PATH> --batch_number <INT> [OPTIONS]
        
        Required arguments:
        --bam_dir                     Path to the directory containing input BAM files
        --output_dir                  Path to the output directory
        --ref_dir                     Path to the reference directory
        --pooled_normal               File name of the .cnn file (eg: pooled_normal.cnn)
        --batch_number                The batch number being processed (eg: 20)
        
        Optional arguments:
        --cpus                        Number of CPUs to use for processing (default: 30)
        --help                        Show this help message and exit
        --legacy                      Run legacy pipeline mode (Check GitHub README for more details)
        --create_pooled_norm          Run specific workflows to generate pooled normal
        Examples:
        
        # Basic usage with required parameters
        nextflow -C nextflow.config run cnvkit.nf --base_dir /path/to/data --ref_dir /path/to/reference --batch_number <INT>
        """
        
        // Print the help and exit
        println(help)
        exit(0)
    }

    // Parameter validation
    if (!params.bam_dir) {
        error "ERROR: --base_dir parameter is required"
        exit 1
    }

    if (!params.output_dir) {
        error "ERROR: --output_dir parameter is required"
        exit 1
    }
    
    if (!params.ref_dir) {
        error "ERROR: --ref_dir parameter is required"
        exit 1
    }

    if (!params.pooled_normal) {
        error "ERROR: --pooled_normal parameter is required"
        exit 1
    }
    
    if (!params.batch_name) {
        error "ERROR: --batch_name parameter is required"
        exit 1
    }

    // workflow logging
    log.info """\
 __     __     ______     ______     __         ______     __  __    
/\\ \\  _ \\ \\   /\\  ___\\   /\\  ___\\   /\\ \\       /\\  ___\\   /\\ \\_\\ \\   
\\ \\ \\/ ".\\ \\  \\ \\  __\\   \\ \\___  \\  \\ \\ \\____  \\ \\  __\\   \\ \\____ \\  
 \\ \\__/".~\\_\\  \\ \\_____\\  \\/\\_____\\  \\ \\_____\\  \\ \\_____\\  \\/\\_____\\ 
  \\/_/   \\/_/   \\/_____/   \\/_____/   \\/_____/   \\/_____/   \\/_____/
=========================================================================================
    Workflow ran:       : ${workflow.manifest.name}
    Command ran         : ${workflow.commandLine}
    Started on          : ${workflow.start}
    Config File used    : ${workflow.configFiles ?: 'None specified'}
    Container(s)        : ${workflow.containerEngine}:${workflow.container ?: 'None'}
    Nextflow Version    : ${workflow.manifest.nextflowVersion}
    """.stripIndent()

    ////////////////////////////
    // Start of main workflow //
    ////////////////////////////

    // channel in the bams as individual tuples, then combine into a list of BAMs
    Channel
        // channel in bams individually
        .fromPath([
                "${params.bam_dir}/*.bam",      // top level directory
                "${params.bam_dir}/**/*.bam"    // subdirectories
            ])
        .filter { !(it =~ /(?i)(PBMC|BLD|CD45|NORM|NORMAL|Blood)/)}  // filter out normal samples (case-insensitive)
        .collect()  // collect each tuple into a list
        .set { tumor_bams }  // set as tumor_bams data structure

    // run CNVKit batch 
    cnr_list = BATCH(tumor_bams)

    // data manipulation
    cnr_files = cnr_list
                    .flatten()  // ungroup list of cnr files for individual processing
                    .map { cnr_file -> 
                                def sample_id = (cnr_file.name =~ /^(.+?)\./)[0][1]  // match patterns before the first "."
                                tuple(sample_id, cnr_file)
                    }

    // run CNVKit segment
    cns_files = SEGMENT(cnr_files)

    // convert .cns files to .seg
    seg_files = EXPORT(cns_files)

    // collect the seg_files into a list
    seg_files
        .collect()
        .set { seg_file_list }

    // merge all the .seg files
    MERGE(seg_file_list)
}