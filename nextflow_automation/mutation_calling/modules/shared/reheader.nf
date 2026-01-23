/*
reheader.nf module

This module renames the headers of each vcf file as it is important for 
downstream tools like 'bcftools isec'.

bcftools version: 1.10.
*/

process REHEADER {
    tag "${sample_id}"
    label 'lowCpu'
    label 'lowMem'
    label 'shortTime'

    input:
    tuple val(sample_id), path(vcf)
    
    output:
    tuple val(sample_id), path("${sample_id}*reheader.vcf")

    script:
    """
    # save the base name to change parameters based on variant caller
    BASE_NAME=\$(basename "${vcf}")

    if [[ "\$BASE_NAME" == *"mutect2.paired"* ]]; then
        # extract header
        chrom_line=\$(grep "^#CHROM" "${vcf}")

        # parse sample names
        sample1=\$(echo "\$chrom_line" | awk '{print \$10}')
        sample2=\$(echo "\$chrom_line" | awk '{print \$11}')

        # Case: TCGB ID Tumor ID, NORMAL
        if [[ "\$sample1" =~ ^[0-9]+[A-Z]?-[0-9]+\$ ]]; then
            # write/append to text files and rearrange columns
            echo "\$sample2" > column-order.txt
            echo "\$sample1" >> column-order.txt
            bcftools view "${vcf}" -S "column-order.txt" > "${sample_id}.mutect2.recolumn.vcf"

            # write text files and reheader the vcfs
            echo "\$sample2 NORMAL" > reheader.txt
            echo "\$sample1 TUMOR" >> reheader.txt
            bcftools reheader "${sample_id}.mutect2.recolumn.vcf" \\
                -s "reheader.txt" \\
                -o "${sample_id}.mutect2.paired.reheader.vcf"

        # Case: Normal Short Lab ID, TCGB ID Tumor ID
        elif [[ "\$sample2" =~ ^[0-9]+[A-Z]?-[0-9]+\$ ]]; then        
            # write text files and reheader the vcfs (no column rearrangement needed)
            echo "\$sample1 NORMAL" > reheader.txt
            echo "\$sample2 TUMOR" >> reheader.txt
            bcftools reheader "${vcf}" \\
                -s "reheader.txt" \\
                -o "${sample_id}.mutect2.paired.reheader.vcf"

        else
            echo "No pattern matched, copying original file"
            cp "${vcf}" "${sample_id}.mutect2.paired.reheader.vcf"
        fi

    elif [[ "\$BASE_NAME" == *"MuSE"* ]]; then
        cp "${vcf}" "${sample_id}.MuSE.reheader.vcf"

    elif [[ "\$BASE_NAME" == *"varscan2"* ]]; then
        cp "${vcf}" "${sample_id}.varscan2.reheader.vcf"

    elif [[ "\$BASE_NAME" == *"mutect2.tumor"* ]]; then
        cp "${vcf}" "${sample_id}.mutect2.tumorOnly.reheader.vcf"
    fi
    """
}