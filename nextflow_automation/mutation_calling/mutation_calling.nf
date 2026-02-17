nextflow.enable.dsl=2

// import modules
include { PILEUP } from './modules/varscan2/pileup.nf'
include { MUSE } from './modules/muse/muse.nf'
include { VARSCAN2 } from './modules/varscan2/varscan2.nf'
include { MUTECT2_CALL } from './modules/mutect2/mutect2_call.nf'
include { GET_PILEUP_SUMMARIES } from './modules/mutect2/get_pileup_summaries.nf'
include { CALCULATE_CONTAMINATION } from './modules/mutect2/calculate_contamination.nf'
include { LEARN_READ_ORIENTATION } from './modules/mutect2/learn_read_orientation.nf'
include { FILTER_MUTECT_CALLS } from './modules/mutect2/filter_mutect_calls.nf'
include { INDEX } from './modules/shared/index.nf'
include { MERGE_VCFS } from './modules/varscan2/merge_vcf.nf'
include { SELECT_VARIANTS } from './modules/shared/select_variants.nf'
include { VEP } from './modules/shared/vep.nf'
include { REHEADER } from './modules/shared/reheader.nf'
include { CREATE_MAF } from './modules/shared/create_maf.nf'
include { KEEP_NONSYNONYMOUS } from './modules/shared/keep_nonsynonymous.nf'
include { RENAME_HG38 } from './modules/shared/rename_hg38.nf'
include { ONCOKB } from './modules/shared/oncokb.nf'
include { MUTECT2_PON } from './modules/mutect2_pon/mutect2_pon.nf'
include { GENOMICS_DB_IMPORT } from './modules/mutect2_pon/genomics_db_import.nf'
include { CREATE_PON } from './modules/mutect2_pon/create_pon.nf'


// define functions for user guidance
def help_message() {
    log.info """Usage:

    The typical command for running the pipeline is as follows:

    nextflow -C <CONFIG_PATH> run mutation_calling.nf --output_dir <PATH> --ref_dir <PATH> --metadata <PATH> --interval_list <PATH> [OPTIONS]

    Required arguments:
    --output_dir                  Path to the output directory for results
    --ref_dir                     Path to the reference directory
    --metadata                    Path to the metadata sheet created by 'make_mc_manifest.py'
    --interval_list               Path to interval list file for targeted analysis

    Optional arguments:
    --cpus                        Number of CPUs to use for processing (default: 30)
    --test_mode                   Enable test mode with reduced dataset (default: false)
    --help                        Show this help message and exit

    Examples:

    # Basic usage with required parameters
    nextflow -C nextflow.config \\
        run mutation_calling.nf \\
        -entry <WORKFLOW_NAME> \\
        --output_dir /path/to/data \\
        --ref_dir /path/to/reference \\
        --metadata /path/to/metadata \\
        --interval_list /path/to/interval_list
    """.stripIndent()
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


def parameter_validation() {
    // Parameter validation (shared across workflows)
    if (!params.output_dir) {
        error "ERROR: --output_dir parameter is required"
        exit 1
    }

    if (!params.ref_dir) {
        error "ERROR: --ref_dir parameter is required"
        exit 1
    }

    if (!params.interval_list) {
        error "ERROR: --interval_list parameter is required"
        exit 1
    }
}


// main workflow
workflow MUTATION_CALLING {
    // Show help message if requested
    if (params.help) {
        help_message()
        exit(0)
    }
    // validate parameters
    parameter_validation()
    if (!params.metadata) {
        error "ERROR: --metadata parameter is required"
        exit 1
    }

    // logging workflow details
    log_workflow()
    
    // channel in metadata and save as a set for downstream processes
    channel
        .fromPath(params.metadata)
        .splitCsv(header: true, sep: '\t')
        .map { row ->
            def sample_id  = row.Sample_ID
            def tumor_id = row.Tumor_ID
            def tumor_bam = row.Tumor_BAM
            def tumor_bai = row.Tumor_BAI != 'NO_FILE' ? row.Tumor_BAI : []
            def tumor_sbi = row.Tumor_SBI != 'NO_FILE' ? row.Tumor_SBI : []
            def normal_id = row.Normal_ID
            def normal_bam = row.Normal_BAM != 'NO_FILE' ? row.Normal_BAM : []
            def normal_bai = row.Normal_BAI != 'NO_FILE' ? row.Normal_BAI : []
            tuple(sample_id, tumor_id, tumor_bam, tumor_bai, tumor_sbi, normal_id, normal_bam, normal_bai)
        }
        .set { bams }

    // split channels based on if normal is available
    bams
    .branch { row ->
        paired: row[6] != []
        tumor_only: row[6] == []
    }
    .set { samples }

    // run Mutect2 steps defined by GATK best practices
    mutect2_calls = MUTECT2_CALL(bams)
    pileup_summaries = GET_PILEUP_SUMMARIES(bams)
    contamination_data = CALCULATE_CONTAMINATION(pileup_summaries)
    orientation_models = LEARN_READ_ORIENTATION(mutect2_calls)
    
    // join contamination and orientation data for filtering
    filter_input = orientation_models
        .join(contamination_data, by: [0, 1, 2])
        .map { sample_id, tumor_id, normal_id, unfiltered_vcf, m2_stats, orientation_model, contamination_table, segments_table ->
            tuple(sample_id, tumor_id, normal_id, unfiltered_vcf, m2_stats, orientation_model, contamination_table, segments_table)
        }
    
    // filter Mutect2 calls
    mutect2_vcfs = FILTER_MUTECT_CALLS(filter_input)

    // run MuSE variant caller
    muse_vcfs = MUSE(samples.paired)

    // run VarScan2 variant caller
    pileups = PILEUP(samples.paired)
    varscan2_raw_vcfs = VARSCAN2(pileups)

    // merge the varscan2 vcfs
    varscan2_vcfs = MERGE_VCFS(varscan2_raw_vcfs)

    // concatenate all the data channels for vcfs
    filtered_vcfs = mutect2_vcfs.concat(muse_vcfs).concat(varscan2_vcfs)

    // compress and index the vcfs
    compressed_vcfs = INDEX(filtered_vcfs)

    // select for passing variants via gatk SelectVariants
    selected_vcfs = SELECT_VARIANTS(compressed_vcfs)

    // annotate for biological effects via VEP
    vep_annotated_vcfs = VEP(selected_vcfs)

    // change the column names in the vcf for standardization
    reheadered_vcfs = REHEADER(vep_annotated_vcfs)

    // generate MAF files
    maf_files = CREATE_MAF(reheadered_vcfs)

    // filter out synonymous mutations
    nonsynonymous_mutations = KEEP_NONSYNONYMOUS(maf_files)

    // rename and reformat the files
    renamed_files = RENAME_HG38(nonsynonymous_mutations)

    // oncokb annotation for clinical relevance
    ONCOKB(renamed_files)
}

workflow CREATE_M2_PON {
    // Show help message if requested
    if (params.help) {
        help_message()
        exit(0)
    }
    // validate parameters
    parameter_validation()
    if (!params.normal_dir) {
        error "ERROR: --normal_dir parameter is required"
        exit 1
    }

    // logging workflow details
    log_workflow()

    // channel in the normal samples
    channel.fromFilePairs([
        "${params.normal_dir}/*.{bam,bam.bai}",
        "${params.normal_dir}/**/*.{bam,bam.bai}"], flat: true)  // generate tuple [sample_id, bam, bai]
    // extract sample ID from filename
    .map { base_name, read1, read2 ->
        def sample_id = base_name.tokenize('.')[0]  // string split, parse first element
        tuple(sample_id, read1, read2) }
    .set { normal_bams }

    // main workflow
    normal_vcfs = MUTECT2_PON(normal_bams)

    // collect vcfs and pass to genomics_db_import
    normal_vcfs
        .collect()
        .set { all_vcfs }

    genomics_db = GENOMICS_DB_IMPORT(all_vcfs)
    
    CREATE_PON(genomics_db)
}