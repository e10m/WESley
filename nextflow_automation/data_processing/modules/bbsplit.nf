/* 
bbsplit.nf module 

This module takes paired-end FASTQ files and uses BBMap's bbsplit tool to
separate reads that align to the mouse reference genome  and those that align
to the human reference genome.

BBMap version: BBMap version 38.06
*/

process SPLIT {
    tag "${sample_id}_${lane}"
    container 'quay.io/biocontainers/bbmap:38.06--0'
    cpus params.cpus

    input:
    tuple val(sample_id), val(lane), path(contaminated_read1), path(contaminated_read2), val(platform), val(seq_center), val(mouse_flag)
    
    output:
    tuple val(sample_id), val(lane), path("${sample_id}_${lane}_hg38_val_1.fq.gz"), path("${sample_id}_${lane}_hg38_val_2.fq.gz"), val(platform), val(seq_center), val(mouse_flag), emit: fastqs
    path("${sample_id}_${lane}.refstats.txt"), emit: stats

    script:
    """
    echo "Splitting $sample_id on $lane..."

    # copy bbsplit ref index/genome to your nextflow working directory if it doesn't already exist
    if [ ! -d ./ref ]; then
        cp -r "/references/ref" ./
    fi

    bbsplit.sh build=99 \
    in1=$contaminated_read1 \
    in2=$contaminated_read2 \
    basename="${sample_id}_${lane}_%_val_#.fq.gz" \
    threads=${task.cpus} \
    refstats="${sample_id}_${lane}.refstats.txt" \
    maxindel=100000 \
    minhits=1 \
    minratio=0.5 \
    ambiguous2=all \
    local
    """
}