/*
main.nf

This is the main nextflow module which conducts the workflow for fixing maf files from the mutation calling.
*/

nextflow.enable.dsl = 2

// import modules
include { REHEADER } from './modules/reheader.nf'
include { CREATE_MAF } from './modules/create_maf.nf'
include { KEEP_NONSYNONYMOUS } from './modules/keep_nonsynonymous.nf'
include { RENAME_HG38 } from './modules/rename_hg38.nf'
include { ONCOKB } from './modules/oncokb.nf'

// main workflow
workflow {
    // channel in vcfs from 3 different variant callers (Mutect2, MuSE, VarScan2)
    vcfs = channel.fromPath("${params.base_dir}/**/*vep.vcf*")
        .map { file -> [file.baseName.replaceAll(/\..*/, ''), file] }

    // standardize vcf columns
    reheadered_vcfs = REHEADER(vcfs)

    // generate MAF files
    mafs = CREATE_MAF(reheadered_vcfs)

    // remove synonymous variant calls
    filtered_mafs = KEEP_NONSYNONYMOUS(mafs)

    // rename hg38
    renamed_filtered_mafs = RENAME_HG38(filtered_mafs)

    // oncokb annotation
    ONCOKB(renamed_filtered_mafs)
}