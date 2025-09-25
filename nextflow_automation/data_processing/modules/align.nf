/* 
align.nf module 

This module takes trimmed FASTQ files ${sample_id}_${lane}_val_{1,2}.fq.gz), aligns them
to the human reference genome via BWA-mem, and uses SAMtools for file manipulation.

samtools version: 1.10
BWA version: 0.7.17
*/

process BWA_ALIGN {
    tag "${sample_id}_${lane}"
    cpus params.cpus

    input:
    tuple val(sample_id), val(lane), path(trimmed_read_1), path(trimmed_read_2), val(platform), val(seq_center), val(mouse_flag)
    
    output:
    tuple val(sample_id), path("${sample_id}_${lane}.sorted.bam")

    script:
    """
    echo "Aligning ${sample_id} on lane ${lane} with platform ${platform} using BWA-mem..."

    # run alignment
    bwa mem \\
        "${params.ref_genome}" \\
        "$trimmed_read_1" \\
        "$trimmed_read_2" \\
        -R "@RG\\tID:${sample_id}\\tSM:${sample_id}\\tPL:${platform}\\tCN:${seq_center}\\tLB:${sample_id}_${lane}\\tDS:${sample_id}_${lane}" \\
        -v 3 \\
        -Y \\
        -M \\
        -t ${task.cpus} \\
        -o "${sample_id}_${lane}.tmp.sam"

    # convert sam file to temporary bam file
    samtools view "${sample_id}_${lane}.tmp.sam" \
    -@ ${task.cpus} \
    -o "${sample_id}_${lane}.tmp.bam" \
    -b -1

    # sort the bam file
    samtools sort -n \
    -@ ${task.cpus} \
    -o "${sample_id}_${lane}.sorted.bam" \
    "${sample_id}_${lane}.tmp.bam"    
    """
}
