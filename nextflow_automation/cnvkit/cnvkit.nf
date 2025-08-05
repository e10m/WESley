/*
main.nf

This is the main nextflow module for orchestrating the workflow of the CNVKit phase of the pipeline.

CNVKit version: 0.9.10
*/

nextflow.enable.dsl = 2

// import modules
include { BATCH } from './modules/batch.nf'
include { SEGMENT } from './modules/segment.nf'
include { EXPORT } from './modules/export.nf'
include { MERGE } from './modules/merge.nf'

// main workflow
workflow {
    // channel in the bams and reference directory as individual tuples
    Channel
    .fromPath("${params.base_dir}/**/*BQSR.bam")
    .map { bam ->
        tuple(bam, params.ref_dir)
    }
    .set { bam_list }

    // group the tuples by the references folder for nested bams list  
    bams_with_ref_nested = bam_list.groupTuple(by: 1)

    // run CNVKit batch 
    cnr_list = BATCH(bams_with_ref_nested)

    cnr_list.flatten().set{cnr_files}

    // run CNVKit segment
    cns_files = SEGMENT(cnr_files)

    // convert .cns files to .seg
    seg_files = EXPORT(cns_files)

    // channel in batch number and combine with the seg_files for renaming
    batch_number = Channel.value(params.batch_number)

    seg_file_list_with_batch  = batch_number.combine(seg_files)

    seg_file_list_with_batch_nested = seg_file_list_with_batch.groupTuple()

    // merge all the .seg files
    MERGE(seg_file_list_with_batch_nested)
}
