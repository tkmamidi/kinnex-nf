process SKERA_SPLIT {
    tag "$meta.pool"
    label 'process_medium'

    input:
    tuple val(meta), path(hifi_bam)
    path mas8_primers

    output:
    tuple val(meta), path("*.segmented.bam"), emit: bam
    tuple val(meta), path("*.segmented.bam.pbi"), emit: pbi, optional: true
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: params.skera_extra_args ?: ''
    def prefix = task.ext.prefix ?: "${meta.pool}"
    """
    skera split \\
        ${hifi_bam} \\
        ${mas8_primers} \\
        ${prefix}.segmented.bam \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        skera: \$(skera --version 2>&1 | grep -oP 'skera \\K[\\d.]+' || echo 'unknown')
    END_VERSIONS
    """
}
