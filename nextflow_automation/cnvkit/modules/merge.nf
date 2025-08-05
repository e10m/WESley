/*
merge.nf

This module merges all .seg files into a singular .seg file.
*/

process MERGE {
    publishDir "${params.base_dir}/cnv_calling/merged_seg_files", mode: 'copy'
    cpus 1
    maxForks 1

    input:
    tuple val(batch_number), path(seg_file_list)
    
    output:
    path("merged_batch_${batch_number}.seg")

    script:
    """
    echo -e "ID\tchrom\tloc.start\tloc.end\tnum.mark\tseg.mean" > merged_${batch_number}.seg
    for f in ${seg_file_list}; do
        tail -n +2 \$f >> "merged_batch_${batch_number}.seg"
    done
    """
}