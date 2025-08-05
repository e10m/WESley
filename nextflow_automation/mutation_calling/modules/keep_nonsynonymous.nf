/* 
keep_nonsynonymous.nf module

This module filters synonymous mutations and keeps nonsynonymous mutation calls only
by referencing the 'nonsynonymous.txt' file.

Ubuntu version: 20.04.
*/

process KEEP_NONSYNONYMOUS {
    tag "${sample_id}"
    cpus 1

    input:
    tuple val(sample_id), path(maf_file)

    output:
    tuple val(sample_id), path("*vep.nonsynonymous.maf")

    script:
    """
    # save the base name to change parameters based on variant caller
    BASE_NAME=\$(basename "${maf_file}")

    if [[ "\$BASE_NAME" == *"mutect2.tumorOnly"* ]]; then
        OUTPUT_NAME="${sample_id}.mutect2.tumorOnly.vep.nonsynonymous.maf"
    elif [[ "\$BASE_NAME" == *"mutect2.paired"* ]]; then
        OUTPUT_NAME="${sample_id}.mutect2.paired.vep.nonsynonymous.maf"
    elif [[ "\$BASE_NAME" == *"MuSE"* ]]; then
        OUTPUT_NAME="${sample_id}.MuSE.vep.nonsynonymous.maf"
    elif [[ "\$BASE_NAME" == *"varscan2"* ]]; then
        OUTPUT_NAME="${sample_id}.varscan2.vep.nonsynonymous.maf"
    fi

    # filter synonymous mutations
    grep -v \
    -w \
    -F \
    -f \
    /references/nonsynonymous.txt $maf_file > "\$OUTPUT_NAME"
    """
}