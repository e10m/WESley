nextflow.enable.dsl = 2

// import modules
include { TRIM } from './modules/trim_adapters.nf'
include { SPLIT } from './modules/bbsplit.nf'
include { BWA_ALIGN } from './modules/align.nf'
include { MARK_DUPES } from './modules/mark_duplicates.nf'
include { SET_TAGS } from './modules/set_tags.nf'
include { RECAL_BASES } from './modules/recal_bases.nf'
include { APPLY_BQSR } from './modules/apply_BQSR.nf'
include { FASTQC } from './modules/fastqc.nf'
include { MULTIQC } from './modules/multiqc.nf'
include { CALC_COVERAGE } from './modules/calc_coverage.nf'


// main workflow
workflow DATA_PROCESSING {
    // Show help message if requested
    if (params.help) {
        help = """Usage:

        The typical command for running the pipeline is as follows:
        
        nextflow -C <CONFIG_FILE> run data_processing.nf --fastq_dir <PATH> --ref_dir <PATH> --metadata <PATH> [OPTIONS]
        
        Required arguments:
        --fastq_dir                   Path to the directory containing input FASTQ data
        --output_dir                  Path to the output directory to publish results
        --ref_dir                     Path to the reference directory
        --metadata                    Path to metadata file
        --batch_name                  Name of the batch for output organization

        Optional arguments:
        --cpus                        Number of CPUs to use for processing (default: 30)
        --help                        Show this help message and exit
        """
        
        // Print the help and exit
        println(help)
        exit(0)
    }
    
    // Parameter validation
    if (!params.fastq_dir) {
        error "ERROR: --fastq_dir parameter is required"
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

    if (!params.metadata) {
        error "ERROR: --metadata parameter is required"
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
    
    // channel in all FASTQ pairs
    channel
        .fromFilePairs([
            "${params.fastq_dir}/*_R{1,2}*.{fastq,fq}{,.gz}",
            "${params.fastq_dir}/**/*_R{1,2}*.{fastq,fq}{,.gz}"], flat: true)  // generate tuple [sample_id, read1, read2]
        // extract sample ID and lane from file base name
        .map { base_name, read1, read2 ->
            def sample_id = (base_name =~ /^\d+\w?-\d+/) ? 
                            (base_name =~ /^(\d+\w?-\d+)/)[0][1] : 
                            (base_name =~ /^(\S+)_S\d+/)[0][1]
            def lane = (base_name =~ /L\d+/)[0]
            tuple(sample_id, lane, read1, read2, params.platform, params.seq_center)}
        // branch reads based on TCGB vs. short ID
        .branch {
            tcgb: it[0] =~ /^\d+\w?-\d+/
            short_id: true
        }
        .set { reads }

    // channel in metadata
    channel
        .fromPath(params.metadata)
        .splitCsv(header: true)
        .map { row ->
            tuple(row."WES ID", row."Short ID") }
        .set { metadata }

    // map TCGB IDs to short IDs
    mapped_tcgb_reads = reads.tcgb
                            .join(metadata, by: 0)  // join the metadata channel with TCGB reads
                            .map { tcgb_id, lane, read1, read2, platform, seq_center, short_id ->
                                def mouse_flag = (short_id =~ /XG?\d+/) ? true : false  // mark xenografts for contamination
                                tuple(short_id, lane, read1, read2, platform, seq_center, mouse_flag) }

    // mark short id reads for mouse contamination
    flagged_short_id_reads = reads.short_id
                                .map { short_id, lane, read1, read2, platform, seq_center ->
                                    def mouse_flag = (short_id =~ /\w+XG?\d+/) ? true : false 
                                    tuple(short_id, lane, read1, read2, platform, seq_center, mouse_flag) }

    // run FASTQC on raw reads
    FASTQC(reads)

    // trim FASTQs using TrimGalore
    trimmed_reads = TRIM(reads)

    // diverge the data channel into contaminated/uncontaminated reads
    uncontaminated_reads = trimmed_reads.filter { it -> it[6] != true }  // mouse_flag is false
    contaminated_reads = trimmed_reads.filter { it -> it[6] == true }  // mouse_flag is true

    // run BBSplit on only mouse-contaminated reads
    SPLIT(contaminated_reads)
    human_fastqs = SPLIT.out.fastqs
    
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
    analysis_ready_bams = APPLY_BQSR(recal_data_tables)

    // use Picard to calculate coverage statistics on analysis ready bams
    CALC_COVERAGE(analysis_ready_bams)

    // run MultiQC once the entire workflow completes
    completion_signal = CALC_COVERAGE.out.stats.collect().map { "ready" }

    MULTIQC(completion_signal)
}
