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