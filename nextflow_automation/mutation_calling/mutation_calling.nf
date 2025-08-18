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
    oncokb_annotated_files = ONCOKB(renamed_files)

    // channel in batch number
    batch_num_channel = channel.value(params.batch_number)

    // combine batch_number into the tuples
    oncokb_annotated_files.combine(batch_num_channel)
}
