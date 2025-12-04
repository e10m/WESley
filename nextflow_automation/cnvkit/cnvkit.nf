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
include { POOL } from './modules/pool.nf'


// define functions for user guidance
def help_message() {
    if (workflow.manifest?.name == "CNV_CALLING") {
        log.info """Usage:

        The typical command for running the pipeline is as follows:
        
        nextflow -C <CONFIG_PATH> run cnvkit.nf -entry "CNV_CALLING" --bam_dir <PATH> --output_dir <PATH> --ref_dir <PATH> --pooled_normal <FILE> --batch_name <STRING> [OPTIONS]
        
        Required arguments:
        --bam_dir                     Path to the directory containing input BAM files
        --output_dir                  Path to the output directory
        --ref_dir                     Path to the reference directory
        --pooled_normal               File name of the pooled normal .cnn file (eg: pooled_normal.cnn)
        --batch_name                  The batch name being processed (eg: batch_01)
        
        Optional arguments:
        --cpus                        Number of CPUs to use for processing (default: 1)
        --legacy                      Run legacy pipeline mode (default: false)
        --help                        Show this help message and exit
        
        Examples:
        
        # Basic usage with required parameters
        nextflow -C nextflow.config run cnvkit.nf -entry "CNV_CALLING" --bam_dir /path/to/bams --output_dir /path/to/output --ref_dir /path/to/reference --pooled_normal pooled_normal.cnn --batch_name batch_01
        
        # With optional parameters
        nextflow -C nextflow.config run cnvkit.nf -entry "CNV_CALLING" --bam_dir /path/to/bams --output_dir /path/to/output --ref_dir /path/to/reference --pooled_normal pooled_normal.cnn --batch_name batch_01 --cpus 30
        """.stripIndent()
        
    }

    if (workflow.manifest?.name == "CREATE_NORM") {
        log.info """Usage:

        The typical command for running the pipeline is as follows:
        
        nextflow -C <CONFIG_PATH> run cnvkit.nf -entry "CREATE_NORM" --bam_dir <PATH> --output_dir <PATH> --ref_dir <PATH> --capture_kit <STRING> --annotation <FILE> --targets <FILE> [OPTIONS]
        
        Required arguments:
        --bam_dir                     Path to the directory containing normal BAM files
        --output_dir                  Path to the output directory
        --capture_kit                 Name of the capture kit (used for naming output files, eg: SeqCap, KAPA, etc.)
        --annotation                  Gene annotation file name (eg: refFlat.txt)
        --targets                     Target BED file name (eg: targets.bed)
        
        Optional arguments:
        --ref_genome                  Reference genome FASTA file name (default: Homo_sapiens_assembly38.fasta)
        --access                      Accessible genomic regions BED file name (default: hg38_access.bed)
        --cpus                        Number of CPUs to use for processing (default: 1)
        --help                        Show this help message and exit
        
        Examples:
        # Basic usage with required parameters
        nextflow -C nextflow.config run cnvkit.nf -entry "CREATE_NORM" --bam_dir /path/to/bams --output_dir /path/to/output --ref_dir /path/to/reference --capture_kit twist_exome --annotation refFlat.txt --targets targets.bed
        """.stripIndent()
    }
    
}

def log_workflow() {
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
}

// main workflow
workflow CNV_CALLING {
    // Show help message if requested
    if (params.help) {
        help_message()
        exit(0)
    }

    // Parameter validation
    if (!params.bam_dir) {
        error "ERROR: --bam_dir parameter is required"
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

    ////////////////////////////
    // Start of main workflow //
    ////////////////////////////

    log_workflow()  // log workflow parameters

    // channel in the bams as individual tuples, then combine into a list of BAMs
    channel
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

workflow CREATE_NORM {
    // show the help message if required
    if (params.help) {
        help_message()
    }

    // Parameter validation
    if (!params.bam_dir) {
        error "ERROR: --bam_dir parameter is required"
        exit 1
    }

    if (!params.ref_dir) {
        error "ERROR: --ref_dir parameter is required"
        exit 1
    }

    if (!params.output_dir) {
        error "ERROR: --output_dir parameter is required"
        exit 1
    }

    if (!params.capture_kit) {
        error "ERROR: --capture_kit parameter is required"
        exit 1
    }

    if (!params.annotation) {
        error "ERROR: --annotation parameter is required"
        exit 1
    }

    if (!params.targets) {
        error "ERROR: --targets parameter is required"
        exit 1
    }

    ////////////////////////////
    // Start of main workflow //
    ////////////////////////////

    log_workflow()

    // channel in the normal bams as individual tuples, then combine into a list of BAMs
    channel
        // channel in bams individually
        .fromPath([
                "${params.bam_dir}/*.bam",      // top level directory
                "${params.bam_dir}/**/*.bam"    // subdirectories
            ])
        .filter { it =~ /(?i)(PBMC|BLD|CD45|NORM|NORMAL|Blood)/ }  // filter out tumor samples (case-insensitive)
        .collect()  // collect each tuple into a list
        .set { normal_bams }  // set as tumor_bams data structure

    // create pooled normal using cnvkit batch
    POOL(normal_bams)
}