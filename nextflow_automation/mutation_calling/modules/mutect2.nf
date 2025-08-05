/* 
mutect2.nf module

This module channels in metadata from the JSON file and performs mutation calling
on the reads using the Mutect2.wdl pipeline for both paired and tumor only samples.

Openjdk/Java Version: 11.0.1.
Cromwell Version: 60
*/

process MUTECT2 {
    tag "${sample_id}"
    cpus 1
    maxForks 1

    input:
    tuple val(sample_id), val(tumor_id), path(tumor_bam), path(tumor_bai), path(tumor_sbi), val(normal_id), path(normal_bam), path(normal_bai), path(json)

    output:
    tuple val(sample_id), val(tumor_id), val(normal_id), path("${sample_id}.mutect2.*.filtered.vcf")

    script:
    """
    # run mutect2 pipeline
    java -jar "${params.app_dir}/cromwell-60.jar" run "${params.app_dir}/mutect2.wdl" -i $json

    # find cromwell execution directory
    CROMWELL_DIR=\$(find . -type d -name "cromwell-executions" | head -1)

    # get the exact filter execution directory
    FILTER_EXEC=\$(find \$CROMWELL_DIR -path "*/call-Filter/execution" | head -1)

    # move the specific files
    if [[ "$json" == *"paired"* ]]; then
        mv "\$FILTER_EXEC/filtered.vcf" "${sample_id}.mutect2.paired.filtered.vcf"
    elif [[ "$json" == *"tumorOnly"* ]]; then
        mv "\$FILTER_EXEC/filtered.vcf" "${sample_id}.mutect2.tumorOnly.filtered.vcf"
    fi
    """
}