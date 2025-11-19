/*
merge.nf

This module merges all .seg files into a singular .seg file.
*/

process MERGE {
    publishDir "${params.output_dir}/cnv_calling/merged_seg_files", mode: 'copy'
    cpus 1

    input:
    path(seg_files)
    
    output:
    path("merged_${params.batch_name}.seg")

    script:
    """
    # create the merged file and add header
    echo -e "ID\tchrom\tloc.start\tloc.end\tnum.mark\tseg.mean" > merged_${params.batch_name}.seg
    
    # append all files, skipping headers
    find . -name "*.seg" -type f -exec tail -n +2 {} \\; >> merged_${params.batch_name}.seg
    """
}