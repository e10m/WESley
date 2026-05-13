nextflow.enable.dsl = 2

// import modules
include { EXTRACT_FINGERPRINT } from './modules/extract_fingerprint.nf'
include { CROSSCHECK_FINGERPRINTS } from './modules/crosscheck_fingerprints.nf'


// ─── shared helpers ─────────────────────────────────────────────────────────

def help_message() {
    def help = """Usage:

    Two entry workflows are available — select one via -entry:

      EXTRACT     Channel BAMs and run Picard ExtractFingerprint to produce per-sample VCFs.
      CROSSCHECK  Channel existing fingerprint VCFs and run Picard CrosscheckFingerprints.

    EXTRACT usage:
      nextflow -C <CONFIG_FILE> run fingerprint.nf -entry EXTRACT \\
          --bam_dir <PATH> --output_dir <PATH> --ref_dir <PATH> --haplotype_map <FILE>

      Required arguments:
        --bam_dir         Path to the directory containing input BAM files
        --output_dir      Path to the output directory to publish results
        --ref_dir         Path to the reference directory
        --haplotype_map   File name of the haplotype map inside ref_dir (eg: hg38_chr1-22XY.map)

    CROSSCHECK usage:
      nextflow -C <CONFIG_FILE> run fingerprint.nf -entry CROSSCHECK \\
          --vcf_dir <PATH> --output_dir <PATH> --ref_dir <PATH> --haplotype_map <FILE>

      Required arguments:
        --vcf_dir         Path to a directory containing fingerprint VCFs (searched recursively)
        --output_dir      Path to the output directory to publish results
        --ref_dir         Path to the reference directory
        --haplotype_map   File name of the haplotype map inside ref_dir (eg: hg38_chr1-22XY.map)

    Optional arguments (both workflows):
      --cpus              Number of CPUs to use for processing (default: 1)
      --help              Show this help message and exit
    """
    println(help)
}

def log_banner() {
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


// ─── EXTRACT: BAMs → per-sample fingerprint VCFs ────────────────────────────

workflow EXTRACT {
    if (params.help) {
        help_message()
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

    log_banner()

    // channel in all BAMs, parse sample_id as everything before .BQSR
    Channel
        .fromPath([
            "${params.bam_dir}/*.bam",
            "${params.bam_dir}/**/*.bam"
        ])
        .map { bam ->
            def sample_id = (bam.name =~ /^(\S+)\.BQSR/)[0][1]  // match everything before the first .BQSR
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
}


// ─── CROSSCHECK: fingerprint VCFs → all-vs-all metrics ──────────────────────

workflow CROSSCHECK {
    if (params.help) {
        help_message()
        exit(0)
    }

    // Parameter validation
    if (!params.vcf_dir) {
        error "ERROR: --vcf_dir parameter is required"
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

    log_banner()

    // channel in all fingerprint VCFs (top-level + recursive) and collect into a list
    Channel
        .fromPath([
            "${params.vcf_dir}/*.vcf",
            "${params.vcf_dir}/**/*.vcf"
        ])
        .collect()
        .set { all_vcfs }

    // run all-vs-all crosscheck across all fingerprint VCFs
    CROSSCHECK_FINGERPRINTS(all_vcfs)
}
