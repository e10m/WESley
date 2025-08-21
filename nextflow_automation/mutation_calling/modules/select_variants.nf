/* 
select_variants.nf module

This module inputs compressed vcf files and subsets the variants based on passing
criteria.

GATK version: 4.2.0.0.
*/

process SELECT_VARIANTS {
    tag "${sample_id}"
    cpus params.cpus
    
    input:
    tuple val(sample_id), val(tumor_id), val(normal_id), path(compressed_vcf), path(index_file)

    output:
    tuple val(sample_id), val(tumor_id), val(normal_id), path("*pass.vcf.gz"), path("*pass.vcf.gz.tbi")

    script:
    """
    # save base name (no file paths) for file name manipulation based on variant caller
    BASE_NAME=\$(basename "${compressed_vcf}")

    # replace file name parts based on variant caller
    if [[ "\$BASE_NAME" == *"mutect2"* ]]; then
        OUTPUT_NAME=\${BASE_NAME/filtered/pass}
    elif [[ "\$BASE_NAME" == *"MuSE"* ]]; then
        OUTPUT_NAME=\${BASE_NAME/sump/pass}
    elif [[ "\$BASE_NAME" == *"varscan2"* ]]; then
        OUTPUT_NAME=\${BASE_NAME/varscan2/varscan2.pass}
    else
        OUTPUT_NAME=\${BASE_NAME/.vcf.gz/.pass.vcf.gz}
    fi

    # run gatk select variants to further filter variants
    gatk SelectVariants \
        -V ${compressed_vcf} \
        -O "\${OUTPUT_NAME}" \
        --exclude-filtered \
        -L chr1 -L chr2 -L chr3 -L chr4 -L chr5 -L chr6 -L chr7 -L chr8 -L chr9 \
        -L chr10 -L chr11 -L chr12 -L chr13 -L chr14 -L chr15 -L chr16 -L chr17 \
        -L chr18 -L chr19 -L chr20 -L chr21 -L chr22 -L chrX -L chrY
    """  
}
