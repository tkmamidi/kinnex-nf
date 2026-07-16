process ISOCALL_PROFILE {
    tag "$meta.sample"
    label 'process_medium'

    input:
    tuple val(meta), path(mapped_bam), path(mapped_bai)

    output:
    tuple val(meta), path("*.profile.gz"), emit: profile
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: params.isocall_extra_args ?: ''
    def prefix = task.ext.prefix ?: "${meta.sample}"
    def isocall_bin = params.isocall_binary
    """
    "${isocall_bin}" profile \\
        --reads ${mapped_bam} \\
        --sample ${prefix} \\
        ${args} \\
        --output ${prefix}.profile.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        isocall: \$("${isocall_bin}" --version 2>&1 | head -1 || echo 'unknown')
    END_VERSIONS
    """
}
