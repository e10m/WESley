nextflow.enable.dsl=2

// import modules
include { MAKE_JSON } from './modules/make_json.nf'
include { PILEUP } from './modules/pileup.nf'
include { MUTECT2 } from './modules/mutect2.nf'
include { MUSE } from './modules/muse.nf'
include { VARSCAN2 } from './modules/varscan2.nf'
include { INDEX } from './modules/index.nf'
include { MERGE_VCFS } from './modules/merge_vcf.nf'
include { SELECT_VARIANTS } from './modules/select_variants.nf'
include { VEP } from './modules/vep.nf'
include { REHEADER } from './modules/reheader.nf'
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

    if (!params.metadata) {
        error "ERROR: --metadata parameter is required"
        exit 1
    }

    if (!params.app_dir) {
        error "ERROR: --app_dir parameter is required"
        exit 1
    }

    // Show help message if requested
    if (params.help) {
        help = """Usage:

        The typical command for running the pipeline is as follows:
        
        nextflow -C <CONFIG_PATH> run mutation_calling.nf --base_dir <PATH> --ref_dir <PATH> --metadata <PATH> --app_dir <PATH> [OPTIONS]
        
        Required arguments:
        --base_dir                    Path to the base directory containing input data
        --ref_dir                     Path to the reference directory
        --metadata                    Path to the metadata sheet created by 'make_mc_metasheet.py'
        --app_dir                     Path to the app directory containing additional scripts and .jar files
        
        Optional arguments:
        --cpus                        Number of CPUs to use for processing (default: 30)
        --help                        Show this help message and exit
        
        Examples:
        
        # Basic usage with required parameters
        nextflow -C nextflow.config \
            run mutation_calling.nf \
            --base_dir /path/to/data \
            --ref_dir /path/to/reference \
            --metadata /path/to/metadata \
            --app_dir /path/to/app
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
    
    // channel in metadata and save as a set for downstream processes
    Channel
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
    bams.branch {
        paired: it[6] != []
        tumor_only: it[6] == []
    }.set { samples }

    // make metadata in JSON format
    json = MAKE_JSON(bams)

    // run the Mutect2 variant caller pipeline
    mutect2_vcfs = MUTECT2(json)

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
