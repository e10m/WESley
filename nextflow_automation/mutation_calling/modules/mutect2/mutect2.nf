/* 
mutect2.nf module

This module performs GATK Mutect2 somatic variant calling following best practices.
Includes the complete pipeline: variant calling, contamination estimation, 
orientation bias modeling, and filtering.

GATK Version: 4.2.0.0
*/

process MUTECT2 {
    tag "${sample_id}"
    cpus 4
    
    input:
    tuple val(sample_id), val(tumor_id), path(tumor_bam), path(tumor_bai), path(tumor_sbi), val(normal_id), path(normal_bam), path(normal_bai)

    output:
    tuple val(sample_id), val(tumor_id), val(normal_id), path("${sample_id}.mutect2.filtered.vcf")

    script:
    // Check if this is paired (tumor-normal) or tumor-only mode
    def normal_args = normal_bam.name != 'NO_FILE' && normal_bam.size() > 0 ? 
        "-I ${normal_bam} -normal ${normal_id}" : ""
    def mode = normal_bam.name != 'NO_FILE' && normal_bam.size() > 0 ? "paired" : "tumorOnly"
    
    """
    # Step 1: Run Mutect2 for initial variant calling
    gatk --java-options "-Xmx3g" Mutect2 \\
        -R /references/Homo_sapiens_assembly38.fasta \\
        -I ${tumor_bam} \\
        ${normal_args} \\
        -tumor ${tumor_id} \\
        --germline-resource /references/af-only-gnomad.hg38.vcf.gz \\
        -L /references/KAPA_HyperExome_hg38_capture_targets.Mutect2.interval_list \\
        --f1r2-tar-gz ${sample_id}.f1r2.tar.gz \\
        -O ${sample_id}.unfiltered.vcf \\
        --genotype-germline-sites true \\
        --genotype-pon-sites true \\
        --max-mnp-distance 0

    # Step 2: Get pileup summaries for contamination estimation
    gatk --java-options "-Xmx3g" GetPileupSummaries \\
        -I ${tumor_bam} \\
        -V /references/small_exac_common_3.hg38.vcf.gz \\
        -L /references/small_exac_common_3.hg38.vcf.gz \\
        -O ${sample_id}.tumor-pileups.table

    # Step 3: Get pileup summaries for normal (if paired mode)
    if [[ "${mode}" == "paired" ]]; then
        gatk --java-options "-Xmx3g" GetPileupSummaries \\
            -I ${normal_bam} \\
            -V /references/small_exac_common_3.hg38.vcf.gz \\
            -L /references/small_exac_common_3.hg38.vcf.gz \\
            -O ${sample_id}.normal-pileups.table
    fi

    # Step 4: Calculate contamination
    if [[ "${mode}" == "paired" ]]; then
        gatk --java-options "-Xmx3g" CalculateContamination \\
            -I ${sample_id}.tumor-pileups.table \\
            -matched ${sample_id}.normal-pileups.table \\
            -O ${sample_id}.contamination.table \\
            --tumor-segmentation ${sample_id}.segments.table
    else
        gatk --java-options "-Xmx3g" CalculateContamination \\
            -I ${sample_id}.tumor-pileups.table \\
            -O ${sample_id}.contamination.table
    fi

    # Step 5: Learn read orientation model for artifact filtering
    gatk --java-options "-Xmx3g" LearnReadOrientationModel \\
        -I ${sample_id}.f1r2.tar.gz \\
        -O ${sample_id}.read-orientation-model.tar.gz

    # Step 6: Filter variants using contamination and orientation bias data
    if [[ "${mode}" == "paired" ]]; then
        gatk --java-options "-Xmx3g" FilterMutectCalls \\
            -V ${sample_id}.unfiltered.vcf \\
            -R /references/Homo_sapiens_assembly38.fasta \\
            --contamination-table ${sample_id}.contamination.table \\
            --tumor-segmentation ${sample_id}.segments.table \\
            --orientation-bias-artifact-priors ${sample_id}.read-orientation-model.tar.gz \\
            -O ${sample_id}.mutect2.filtered.vcf
    else
        gatk --java-options "-Xmx3g" FilterMutectCalls \\
            -V ${sample_id}.unfiltered.vcf \\
            -R /references/Homo_sapiens_assembly38.fasta \\
            --contamination-table ${sample_id}.contamination.table \\
            --orientation-bias-artifact-priors ${sample_id}.read-orientation-model.tar.gz \\
            -O ${sample_id}.mutect2.filtered.vcf
    fi

    # Clean up intermediate files
    rm -f ${sample_id}.unfiltered.vcf* \\
          ${sample_id}.f1r2.tar.gz \\
          ${sample_id}.*pileups.table \\
          ${sample_id}.contamination.table \\
          ${sample_id}.segments.table \\
          ${sample_id}.read-orientation-model.tar.gz
    """
}