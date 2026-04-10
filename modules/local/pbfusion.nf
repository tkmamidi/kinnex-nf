process PBFUSION {
    tag "$meta.sample"
    label 'process_low'

    input:
    tuple val(meta), path(mapped_bam), path(mapped_bai)
    path ref_annotation

    output:
    tuple val(meta), path("*.breakpoints.groups.bed"), emit: fusions, optional: true
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: params.pbfusion_extra_args ?: ''
    def prefix = task.ext.prefix ?: "${meta.sample}"
    """
    pbfusion discover \\
        --gtf ${ref_annotation} \\
        --output-prefix ${prefix} \\
        --threads ${task.cpus} \\
        ${args} \\
        ${mapped_bam}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pbfusion: \$(pbfusion discover --version 2>&1 | sed 's/pbfusion-discover //')
    END_VERSIONS
    """
}
