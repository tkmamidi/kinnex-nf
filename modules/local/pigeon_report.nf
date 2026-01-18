process PIGEON_REPORT {
    tag "$meta.sample"
    label 'process_low'

    input:
    tuple val(meta), path(filtered_classification)

    output:
    tuple val(meta), path("*.saturation.txt"), emit: saturation
    tuple val(meta), path("*.report.json"), emit: report
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: params.pigeon_report_extra_args ?: ''
    def prefix = task.ext.prefix ?: "${meta.sample}"
    """
    pigeon report \\
        ${args} \\
        ${filtered_classification} \\
        ${prefix}.saturation.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pigeon: \$(pigeon --version 2>&1 | grep -oP 'pigeon \\K[\\d.]+' || echo 'unknown')
    END_VERSIONS
    """
}
