/* 
vep.nf module

This module inputs the selected variant vcf files and annotates them for biological
effects, phenotype association, allele frequency reporting, and deleteriousness predictions using VEP.

Ensembl VEP Version: 106.
VEP Cache Version: 103.
*/

process VEP {
    tag "${sample_id}"
    publishDir "${params.base_dir}/mutation_calls/consensus/vep_annotated_vcfs", mode: 'copy', pattern: "*vep.vcf"
    
    input:
    tuple val(sample_id), path(consensus_vcf)

    output:
    tuple val(sample_id), path("${sample_id}.consensus.vep.vcf")

    script:
    """
    # annotate via VEP
    vep \
    --vcf \
    --input_file $consensus_vcf \
    --output_file "${sample_id}.consensus.vep.vcf" \
    --everything \
    --species homo_sapiens \
    --no_stats \
    --fork ${task.cpus} \
    --cache \
    --offline \
    --fasta /references/Homo_sapiens_assembly38.fasta \
    --dir_cache /opt/vep/.vep \
    --cache_version 103
    """
}