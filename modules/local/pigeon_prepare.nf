process PIGEON_PREPARE {
    tag "$meta.sample"
    label 'process_low'

    input:
    tuple val(meta), path(collapsed_gff)

    output:
    tuple val(meta), path("*.sorted.gff"), emit: gff
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.sample}"
    """
    pigeon prepare \\
        ${collapsed_gff}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pigeon: \$(pigeon --version 2>&1 | grep -oP 'pigeon \\K[\\d.]+' || echo 'unknown')
    END_VERSIONS
    """
}
