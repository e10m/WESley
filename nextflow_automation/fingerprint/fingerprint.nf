nextflow.enable.dsl = 2

// import modules
include { EXTRACT_FINGERPRINT } from './modules/extract_fingerprint.nf'
include { CROSSCHECK_FINGERPRINTS } from './modules/crosscheck_fingerprints.nf'


// main workflow
workflow FINGERPRINT {
    // Show help message if requested
    if (params.help) {
        help = """Usage:

        The typical command for running the pipeline is as follows:

        nextflow -C <CONFIG_FILE> run fingerprint.nf --bam_dir <PATH> --output_dir <PATH> --ref_dir <PATH> --haplotype_map <FILE> [OPTIONS]

        Required arguments:
        --bam_dir                     Path to the directory containing input BAM files
        --output_dir                  Path to the output directory to publish results
        --ref_dir                     Path to the reference directory
        --haplotype_map               File name of the haplotype map inside ref_dir (eg: hg38_chr1-22XY.map)

        Optional arguments:
        --cpus                        Number of CPUs to use for processing (default: 4)
        --help                        Show this help message and exit
        """

        // Print the help and exit
        println(help)
        exit(0)
    }

    // Parameter validation
    if (!params.bam_dir) {
        error "ERROR: --bam_dir parameter is required"
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

    if (!params.haplotype_map) {
        error "ERROR: --haplotype_map parameter is required"
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

    // channel in all BAMs, parse sample_id as everything before the first dot
    Channel
        .fromPath([
            "${params.bam_dir}/*.bam",
            "${params.bam_dir}/**/*.bam"
        ])
        .map { bam ->
            def sample_id = (bam.name =~ /^(.+?)\./)[0][1]
            def bai = file("${bam}.bai").exists() ?
                      file("${bam}.bai") :
                      file("${bam.toString().replace('.bam', '.bai')}").exists() ?
                      file("${bam.toString().replace('.bam', '.bai')}") :
                      []
            tuple(sample_id, bam, bai)
        }
        .set { all_bams }

    // extract per-sample fingerprint VCFs
    EXTRACT_FINGERPRINT(all_bams)

    // run all-vs-all crosscheck across all fingerprint VCFs
    CROSSCHECK_FINGERPRINTS(EXTRACT_FINGERPRINT.out.vcf.collect())
}
