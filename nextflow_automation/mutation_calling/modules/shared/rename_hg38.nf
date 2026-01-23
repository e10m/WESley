/* 
rename_hg38.nf

This module renames all instances of 'hg38' to 'GRCh38' in the maf files.

Ubuntu version: 20.04.
*/

process RENAME_HG38 {
    tag "${sample_id}"
    label 'lowCpu'
    label 'lowMem'
    label 'shortTime'

    input:
    tuple val(sample_id), path(nonsyno_maf)

    output:
    tuple val(sample_id), path("*vep.nonsynonymous.rename.maf")

    script:
    """
    # save the base name to change parameters based on variant caller
    BASE_NAME=\$(basename "${nonsyno_maf}")

    if [[ "\$BASE_NAME" == *"mutect2.tumorOnly"* ]]; then
        OUTPUT_NAME="${sample_id}.mutect2.tumorOnly.vep.nonsynonymous.rename.maf"
    elif [[ "\$BASE_NAME" == *"mutect2.paired"* ]]; then
        OUTPUT_NAME="${sample_id}.mutect2.paired.vep.nonsynonymous.rename.maf"
    elif [[ "\$BASE_NAME" == *"MuSE"* ]]; then
        OUTPUT_NAME="${sample_id}.MuSE.vep.nonsynonymous.rename.maf"
    elif [[ "\$BASE_NAME" == *"varscan2"* ]]; then
        OUTPUT_NAME="${sample_id}.varscan2.vep.nonsynonymous.rename.maf"
    fi
    
    # rename the output file name and the 'hg38' instances within file
    sed 's/hg38/GRCh38/g' "$nonsyno_maf" > "\$OUTPUT_NAME"
    """
}