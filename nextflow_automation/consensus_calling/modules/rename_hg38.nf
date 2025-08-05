/* 
rename_hg38.nf

This module renames all instances of 'hg38' to 'GRCh38' in the maf files.

Ubuntu version: 20.04.
*/

process RENAME_HG38 {
    tag "${sample_id}"
    
    input:
    tuple val(sample_id), path(nonsyno_maf)

    output:
    tuple val(sample_id), path("*vep.nonsynonymous.rename.maf")

    script:
    """
    # rename the output file name and the 'hg38' instances within file
    sed 's/hg38/GRCh38/g' "$nonsyno_maf" > "${sample_id}.consensus.vep.nonsynonymous.rename.maf"
    """
}