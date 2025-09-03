/* 
make_json.nf module

This module inputs the metadata information and creates a JSON file
containing the necessary metadata and parameters to run the mutect2.wdl 
variant caller pipeline for both paired / tumor-only mode.

Ubuntu version: 20.04.
*/

process MAKE_JSON {
    tag "${sample_id}"
    cpus 1

    input:
    tuple val(sample_id), val(tumor_id), path(tumor_bam), path(tumor_bai), path(tumor_sbi), val(normal_id), path(normal_bam, stageAs: "normal.bam"), path(normal_bai, stageAs: "normal.bai")

    output:
    tuple val(sample_id), val(tumor_id), path(tumor_bam), path(tumor_bai), path(tumor_sbi), val(normal_id), path("normal.bam"), path("normal.bai"), path("${sample_id}.mutect2*.json")

    script:
    """
    # create JSON files for tumor-only mode
    if [[ "${normal_bam}" == "" ]]; then
        cat <<EOF > "${sample_id}.mutect2.tumorOnly.json"
        {
                "Mutect2.gatk_docker"                               : "broadinstitute/gatk:4.2.0.0",
                "Mutect2.gatk_override"                             : "${params.app_dir}/gatk-package-4.2.0.0-local.jar",
                "Mutect2.intervals"                                 : "${params.ref_dir}/KAPA_HyperExome_hg38_capture_targets.Mutect2.interval_list",
                "Mutect2.scatter_count"                             : 30,
                "Mutect2.m2_extra_args"                             : "--genotype-germline-sites true --genotype-pon-sites true --downsampling-stride 20 --max-reads-per-alignment-start 0 --max-mnp-distance 0 --max-suspicious-reads-per-alignment-start 6 -ip 200",
                "Mutect2.run_orientation_bias_mixture_model_filter" : true,
                "Mutect2.ref_fasta"                                 : "${params.ref_dir}/Homo_sapiens_assembly38.fasta",
                "Mutect2.ref_dict"                                  : "${params.ref_dir}/Homo_sapiens_assembly38.dict",
                "Mutect2.ref_fai"                                   : "${params.ref_dir}/Homo_sapiens_assembly38.fasta.fai",
                "Mutect2.tumor_reads"                               : "${tumor_bam}",
                "Mutect2.tumor_reads_index"                         : "${tumor_bai}",
                "Mutect2.gnomad"                                    : "${params.ref_dir}/af-only-gnomad.hg38.vcf.gz",
                "Mutect2.gnomad_idx"                                : "${params.ref_dir}/af-only-gnomad.hg38.vcf.gz.tbi"
        }
EOF
    
    # generate placeholder text file for nextflow data channeling (tumor only cases)
    touch normal.bam
    touch normal.bai
    
    # create JSON files for matched normals
    else
        cat <<EOF > "${sample_id}.mutect2.paired.json"
        {
            "Mutect2.gatk_docker": "broadinstitute/gatk:4.2.0.0",
            "Mutect2.gatk_override": "${params.app_dir}/gatk-package-4.2.0.0-local.jar",
            "Mutect2.intervals": "${params.ref_dir}/KAPA_HyperExome_hg38_capture_targets.Mutect2.interval_list",
            "Mutect2.scatter_count": 30,
            "Mutect2.m2_extra_args": "--downsampling-stride 20 --max-reads-per-alignment-start 0 --max-suspicious-reads-per-alignment-start 6 -ip 200",
            "Mutect2.run_orientation_bias_mixture_model_filter": true,
            "Mutect2.ref_fasta": "${params.ref_dir}/Homo_sapiens_assembly38.fasta",
            "Mutect2.ref_dict": "${params.ref_dir}/Homo_sapiens_assembly38.dict",
            "Mutect2.ref_fai": "${params.ref_dir}/Homo_sapiens_assembly38.fasta.fai",
            "Mutect2.normal_reads": "${normal_bam}",
            "Mutect2.normal_reads_index": "${normal_bai}",
            "Mutect2.tumor_reads": "${tumor_bam}",
            "Mutect2.tumor_reads_index": "${tumor_bai}",
            "Mutect2.gnomad": "${params.ref_dir}/af-only-gnomad.hg38.vcf.gz",
            "Mutect2.gnomad_idx": "${params.ref_dir}/af-only-gnomad.hg38.vcf.gz.tbi",
            "Mutect2.variants_for_contamination": "${params.ref_dir}/small_exac_common_3.hg38.vcf.gz",
            "Mutect2.variants_for_contamination_idx": "${params.ref_dir}/small_exac_common_3.hg38.vcf.gz.tbi"
        }
EOF
    fi
    """    
}