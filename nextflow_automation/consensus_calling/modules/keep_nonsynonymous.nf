/* 
keep_nonsynonymous.nf module

This module filters synonymous mutations and keeps nonsynonymous mutation calls only
by referencing the 'nonsynonymous.txt' file.

Ubuntu version: 20.04.
*/

process KEEP_NONSYNONYMOUS {
    tag "${sample_id}"
    label 'lowCpu'
    label 'lowMem'
    label 'shortTime'

    input:
    tuple val(sample_id), path(maf_file)

    output:
    tuple val(sample_id), path("*vep.nonsynonymous.maf")

    script:
    """
    # filter synonymous mutations
    grep -v \
    -w \
    -F \
    -f \
    /references/nonsynonymous.txt $maf_file > "${sample_id}.consensus.vep.nonsynonymous.maf"
    """
}