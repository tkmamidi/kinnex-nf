process LIMA {
    tag "$meta.pool"
    label 'process_high'

    input:
    tuple val(meta), path(segmented_bam)
    path primers
    path biosample_csv

    output:
    tuple val(meta), path("*.lima.*.bam"), emit: bam
    tuple val(meta), path("*.lima.*.bam.pbi"), emit: pbi, optional: true
    tuple val(meta), path("*.lima.summary"), emit: summary
    tuple val(meta), path("*.lima.counts"), emit: counts
    tuple val(meta), path("*.lima.report"), emit: report
    tuple val(meta), path("*.lima.log"), emit: log
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: params.lima_extra_args ?: ''
    def prefix = task.ext.prefix ?: "${meta.pool}"
    """
    lima \\
        -j ${task.cpus} \\
        ${args} \\
        --log-level INFO \\
        --log-file ${prefix}.lima.log \\
        --biosample-csv ${biosample_csv} \\
        ${segmented_bam} \\
        ${primers} \\
        ${prefix}.lima.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        lima: \$(lima --version 2>&1 | grep -oP 'lima \\K[\\d.]+' || echo 'unknown')
    END_VERSIONS
    """
}
