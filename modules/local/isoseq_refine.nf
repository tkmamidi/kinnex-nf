process ISOSEQ_REFINE {
    tag "$meta.sample"
    label 'process_high'

    input:
    tuple val(meta), path(lima_bam)
    path primers

    output:
    tuple val(meta), path("*.flnc.bam"), emit: bam
    tuple val(meta), path("*.flnc.bam.pbi"), emit: pbi, optional: true
    tuple val(meta), path("*.flnc.report.csv"), emit: report
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: params.isoseq_refine_extra_args ?: ''
    def prefix = task.ext.prefix ?: "${meta.sample}"
    """
    isoseq refine \\
        -j ${task.cpus} \\
        ${args} \\
        ${lima_bam} \\
        ${primers} \\
        ${prefix}.flnc.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        isoseq: \$(isoseq --version 2>&1 | grep -oP 'isoseq \\K[\\d.]+' || echo 'unknown')
    END_VERSIONS
    """
}
