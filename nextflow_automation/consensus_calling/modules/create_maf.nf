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
    tuple val(sample_id), path(consensus_vcf)

    output:
    tuple val(sample_id), path("*.maf")

    script:
    """
    # create MAF command
    perl /app/vcf2maf.pl \
    --inhibit-vep \
    --input-vcf $consensus_vcf \
    --output-maf "${sample_id}.consensus.vep.maf" \
    --tumor-id $sample_id \
    --normal-id "NORMAL" \
    --vcf-tumor-id "TUMOR" \
    --vcf-normal-id "NORMAL" \
    --ref-fasta /references/Homo_sapiens_assembly38.fasta \
    --ncbi-build hg38 \
    --maf-center NathansonLab
    """
}