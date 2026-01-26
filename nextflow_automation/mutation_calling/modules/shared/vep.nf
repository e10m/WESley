/* 
vep.nf module

This module inputs the selected variant vcf files and annotates them for biological
effects, phenotype association, allele frequency reporting, and deleteriousness predictions using VEP.

Ensembl VEP Version: 106.
VEP Cache Version: 103.
*/

process VEP {
    tag "${sample_id}"
    publishDir "${params.output_dir}/mutation_calls/mutect2/vep_annotated_vcfs", mode: 'copy', pattern: "*mutect2*vep.vcf*"
    publishDir "${params.output_dir}/mutation_calls/MuSE/vep_annotated_vcfs", mode: 'copy', pattern: "*MuSE*vep.vcf*"
    publishDir "${params.output_dir}/mutation_calls/varscan2/vep_annotated_vcfs", mode: 'copy', pattern: "*varscan2*vep.vcf*"
    label 'medCpu'
    label 'medMem'
    label 'medTime'

    input:
    tuple val(sample_id), val(tumor_id), val(normal_id), path(selected_vcf), path(index_file)

    output:
    tuple val(sample_id), path("*vep.vcf")

    script:
    """
    # save base name (no file paths) for file name manipulation based on variant caller
    BASE_NAME=\$(basename "${selected_vcf}")

    # replace file name parts based on variant caller
    OUTPUT_NAME=\${BASE_NAME/pass/vep}

    # annotate via VEP
    vep \
    --vcf \
    --input_file $selected_vcf \
    --output_file "\${OUTPUT_NAME%.gz}" \
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
