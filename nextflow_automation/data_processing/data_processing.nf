nextflow.enable.dsl = 2

// import modules
include { TRIM } from './modules/trim_adapters.nf'
include { SPLIT } from './modules/bbsplit.nf'
include { BWA_ALIGN } from './modules/align.nf'
include { MARK_DUPES } from './modules/mark_duplicates.nf'
include { SET_TAGS } from './modules/set_tags.nf'
include { RECAL_BASES } from './modules/recal_bases.nf'
include { APPLY_BQSR } from './modules/apply_BQSR.nf'
include { FASTQC_RAW } from './modules/fastqc_raw.nf'
include { FASTQC_TRIMMED } from './modules/fastqc_trimmed.nf'
include { FASTQC_BBSPLIT } from './modules/fastqc_bbsplit.nf'
include { MULTIQC } from './modules/multiqc.nf'

// main workflow
workflow {
    // Show help message if requested
    if (params.help) {
        help = """Usage:

        The typical command for running the pipeline is as follows:
        
        nextflow -C <CONFIG_FILE> run data_processing.nf --base_dir <PATH> --ref_dir <PATH> --metadata <PATH> [OPTIONS]
        
        Required arguments:
        --base_dir                    Path to the base directory containing input data
        --ref_dir                     Path to the reference directory
        --metadata                    Path to metadata file

        Optional arguments:
        --cpus                        Number of CPUs to use for processing (default: 30)
        --help                        Show this help message and exit
        
        Examples:
        
        # Basic usage with required parameters
        nextflow -C nextflow.config run data_processing.nf --base_dir /path/to/data --ref_dir /path/to/reference --metadata /path/to/metadata
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

    if (!params.metadata) {
        error "ERROR: --metadata parameter is required"
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
    
    // channel in metadata and save as a set for downstream processes
    Channel
        .fromPath(params.metadata)
        .splitCsv(header: true, sep: '\t')
        .map { row ->
            def sample_id  = row.Sample_ID
            def lane       = row.Lane
            def fastq_1    = file("${params.base_dir}/**/${row.FASTQ_R1}")
            def fastq_2    = file("${params.base_dir}/**/${row.FASTQ_R2}")
            def platform   = row.Platform
            def seq_center = row.Sequencing_Center
            def mouse_flag = row.Mouse_Flag.toLowerCase() == 'true'
            tuple(sample_id, lane, fastq_1, fastq_2, platform, seq_center, mouse_flag)
        }
        .set { reads }

    // run FASTQC on raw reads
    FASTQC_RAW(reads)

    // trim FASTQs using TrimGalore
    trimmed_reads = TRIM(reads)

    // FASTQC on trimmed reads
    FASTQC_TRIMMED(trimmed_reads)

    // diverge the data channel into contaminated/uncontaminated reads
    uncontaminated_reads = trimmed_reads.filter { it -> it[6] != true }  // mouse_flag is false
    contaminated_reads = trimmed_reads.filter { it -> it[6] == true }  // mouse_flag is true

    // run BBSplit on only mouse-contaminated reads
    SPLIT(contaminated_reads)
    human_fastqs = SPLIT.out.fastqs

    // run FASTQC on human reads
    FASTQC_BBSPLIT(human_fastqs)
    
    // concatenate the channels and converge data channels again
    merged_uncontaminated_reads = uncontaminated_reads.concat(human_fastqs)    

    // align trimmed FASTQs via BWA-mem
    sorted_bam_files = BWA_ALIGN(merged_uncontaminated_reads)

    // group the lane-specific BAMs for each sample
    sorted_bam_files
        // group by sample ID
        .groupTuple(by: 0)

        // flatten the list  
        .map { sample_id, bam_list ->
                tuple(sample_id, bam_list)
            }
        
        // store in list
        .set { sorted_bams }

    // merge BAMs and mark duplicates
    marked_bams = MARK_DUPES(sorted_bams)

    // set up tags for the BAMs and combine with reference directory
    tagged_bams = SET_TAGS(marked_bams)

    // recalibrate base quality scores and combine with reference directory
    recal_data_tables = RECAL_BASES(tagged_bams)

    // apply the BQSR algorithm
    APPLY_BQSR(recal_data_tables)
    
    // run MultiQC once the entire workflow completes
    completion_signal = APPLY_BQSR.out.collect().map { "ready" }
    MULTIQC(completion_signal)
}
