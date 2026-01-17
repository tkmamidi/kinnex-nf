process PIGEON_FILTER {
    tag "$meta.sample"
    label 'process_medium'

    input:
    tuple val(meta), path(classification), path(junctions), path(sorted_gff)

    output:
    tuple val(meta), path("*_classification.filtered_lite_classification.txt"), emit: filtered_classification
    tuple val(meta), path("*_classification.filtered_lite_reasons.txt"), emit: filtered_reasons, optional: true
    tuple val(meta), path("*.filtered_lite.gff"), emit: filtered_gff, optional: true
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: params.pigeon_filter_extra_args ?: ''
    def prefix = task.ext.prefix ?: "${meta.sample}"
    """
    pigeon filter \\
        ${args} \\
        ${classification} \\
        --isoforms ${sorted_gff}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pigeon: \$(pigeon --version 2>&1 | grep -oP 'pigeon \\K[\\d.]+' || echo 'unknown')
    END_VERSIONS
    """
}
