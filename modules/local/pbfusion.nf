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
    def pbfusion_bin = params.pbfusion_binary ?: 'pbfusion'
    """
    ${pbfusion_bin} discover \\
        --gtf ${ref_annotation} \\
        --output-prefix ${prefix} \\
        ${args} \\
        ${mapped_bam}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pbfusion: \$(${pbfusion_bin} --version 2>&1 | sed 's/pbfusion //')
    END_VERSIONS
    """
}
