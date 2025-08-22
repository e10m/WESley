/*
main.nf

This is the main nextflow module which conducts the workflow for Consensus Calling
*/

nextflow.enable.dsl = 2

// import modules
include { SORT_VCFS } from './modules/sort_vcfs.nf'
include { REHEADER } from './modules/reheader.nf'
include { INDEX } from './modules/index.nf'
include { INTERSECT } from './modules/intersect.nf'
include { MERGE_VCFS } from './modules/merge_vcfs.nf'
include { NORM_INDELS } from './modules/norm_indels.nf'
include { VEP } from './modules/vep.nf'
include { CREATE_MAF } from './modules/create_maf.nf'
include { KEEP_NONSYNONYMOUS } from './modules/keep_nonsynonymous.nf'
include { RENAME_HG38 } from './modules/rename_hg38.nf'
include { ONCOKB } from './modules/oncokb.nf'

// main workflow
workflow {
    // Parameter validation
    if (!params.base_dir) {
        error "ERROR: --base_dir parameter is required"
        exit 1
    }

    if (!params.ref_dir) {
        error "ERROR: --ref_dir parameter is required"
        exit 1
    }

    // Show help message if requested
    if (params.help) {
        help = """Usage:

        The typical command for running the pipeline is as follows:
        
        nextflow -C <CONFIG_PATH> run consensus_calling.nf --base_dir <PATH> --ref_dir <PATH> [OPTIONS]
        
        Required arguments:
        --base_dir                    Path to the base directory containing input data
        --ref_dir                     Path to the reference directory
        
        Optional arguments:
        --cpus                        Number of CPUs to use for processing (default: 30)
        --help                        Show this help message and exit
        
        Examples:
        
        # Basic usage with required parameters
        nextflow -C nextflow.config \
            run consensus_calling.nf \
            --base_dir /path/to/data \
            --ref_dir /path/to/reference \
        """

        // Print the help and exit
        println(help)
        exit(0)
    }

    // workflow logging
    log.info """/
    ${params.manifest.name ?: 'Unknown'} v${params.manifest.version ?: 'Unknown'}
    ===================================================
    Command ran         : ${workflow.commandLine}
    Started on          : ${workflow.start}
    Config File used    : ${workflow.configFiles ?: 'None specified'}
    Container(s)        : ${workflow.containerEngine}:${workflow.container ?: 'None'}
    """.stripIndent()

    ////////////////////////////
    // Start of main workflow //
    ////////////////////////////

    // channel in vcfs from 3 different variant callers (Mutect2, MuSE, VarScan2)
    mutect2_vcfs = channel.fromPath("${params.base_dir}/**/*mutect2.paired.vep.vcf*")
        .map { file -> [file.baseName.replaceAll(/\.mutect2.*/, ''), file] }
    
    muse_vcfs = channel.fromPath("${params.base_dir}/**/*MuSE.vep.vcf*")
        .map { file -> [file.baseName.replaceAll(/\.MuSE.*/, ''), file] }
    
    varscan_vcfs = channel.fromPath("${params.base_dir}/**/*varscan2.vep.vcf*")
        .map { file -> [file.baseName.replaceAll(/\.varscan2.*/, ''), file] }

    // combine all three caller results by sample_id
    vcfs = mutect2_vcfs
        .join(muse_vcfs)
        .join(varscan_vcfs)
        .map { sample_id, mutect2_vcf, muse_vcf, varscan_vcf -> 
            [sample_id, mutect2_vcf, muse_vcf, varscan_vcf]
        }
    
    // sort vcfs
    sorted_vcfs = SORT_VCFS(vcfs)

    // reheader the vcfs
    reheadered_vcfs = REHEADER(sorted_vcfs)

    // compress and index vcfs
    compressed_vcfs = INDEX(reheadered_vcfs)

    // bcftools intersect for consensus filtering
    consensus_vcfs = INTERSECT(compressed_vcfs)

    // merge vcfs
    merged_consensus_vcfs = MERGE_VCFS(consensus_vcfs)

    // delete duplicates using indel normalization
    filtered_consensus_vcfs = NORM_INDELS(merged_consensus_vcfs)

    // vep annotation
    annotated_consensus_vcfs = VEP(filtered_consensus_vcfs)

    // generate MAF files
    consensus_mafs = CREATE_MAF(annotated_consensus_vcfs)

    // remove synonymous variant calls
    filtered_consensus_mafs = KEEP_NONSYNONYMOUS(consensus_mafs)

    // rename hg38
    renamed_consensus_mafs = RENAME_HG38(filtered_consensus_mafs)

    // oncokb annotation
    ONCOKB(renamed_consensus_mafs)
}