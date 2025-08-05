/* 
create_maf.nf module

This module uses the vcf2maf.pl script to convert the vep-annotated
VCF files into MAF files.

vcf2maf.pl version: 1.6.17.
*/

process CREATE_MAF {
    tag "${sample_id}"
    cpus 1

    input:
    tuple val(sample_id), path(vcf)

    output:
    tuple val(sample_id), path("*.maf")

    script:
    """
    # save the base name to change parameters based on variant caller
    BASE_NAME=\$(basename "${vcf}")

    if [[ "\$BASE_NAME" == *"mutect2.tumorOnly"* ]]; then
        OUTPUT_NAME="${sample_id}.mutect2.tumorOnly.vep.maf"
    elif [[ "\$BASE_NAME" == *"mutect2.paired"* ]]; then
        OUTPUT_NAME="${sample_id}.mutect2.paired.vep.maf"
    elif [[ "\$BASE_NAME" == *"MuSE"* ]]; then
        OUTPUT_NAME="${sample_id}.MuSE.vep.maf"
    elif [[ "\$BASE_NAME" == *"varscan2"* ]]; then
        OUTPUT_NAME="${sample_id}.varscan2.vep.maf"
    fi

    # creating mafs for tumor only samples
    if [[ "\$BASE_NAME" == *"mutect2.tumorOnly"* ]]; then
        # create MAF command
        perl /app/vcf2maf.pl \
            --inhibit-vep \
            --input-vcf ${vcf} \
            --output-maf "\$OUTPUT_NAME" \
            --tumor-id ${sample_id} \
            --vcf-tumor-id ${sample_id} \
            --ref-fasta /references/Homo_sapiens_assembly38.fasta \
            --ncbi-build hg38 \
            --maf-center NathansonLab

    # create maf for matched samples
    else
        # create MAF command
        perl /app/vcf2maf.pl \
            --inhibit-vep \
            --input-vcf ${vcf} \
            --output-maf "\$OUTPUT_NAME" \
            --tumor-id ${sample_id} \
            --normal-id "NORMAL" \
            --vcf-tumor-id "TUMOR" \
            --vcf-normal-id "NORMAL" \
            --ref-fasta /references/Homo_sapiens_assembly38.fasta \
            --ncbi-build hg38 \
            --maf-center NathansonLab
    fi
    """
}