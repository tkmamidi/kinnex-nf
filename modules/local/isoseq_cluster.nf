process ISOSEQ_CLUSTER {
    tag "$meta.sample"
    label 'process_high'

    input:
    tuple val(meta), path(flnc_bam)

    output:
    tuple val(meta), path("*.clustered.bam"), emit: bam
    tuple val(meta), path("*.clustered.bam.pbi"), emit: pbi, optional: true
    tuple val(meta), path("*.clustered.hq.bam"), emit: hq_bam, optional: true
    tuple val(meta), path("*.clustered.lq.bam"), emit: lq_bam, optional: true
    tuple val(meta), path("*.clustered.cluster_report.csv"), emit: report, optional: true
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: params.isoseq_cluster_extra_args ?: ''
    def prefix = task.ext.prefix ?: "${meta.sample}"
    """
    isoseq cluster2 \\
        -j ${task.cpus} \\
        ${args} \\
        ${flnc_bam} \\
        ${prefix}.clustered.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        isoseq: \$(isoseq --version 2>&1 | grep -oP 'isoseq \\K[\\d.]+' || echo 'unknown')
    END_VERSIONS
    """
}
