process ISOCALL_PREP {
    tag "reference"
    label 'process_low'

    input:
    path ref_annotation

    output:
    path "ref.isoforms.gz", emit: isoforms
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def isocall_bin = params.isocall_binary
    """
    ${isocall_bin} prep-isoforms \\
        --gtf ${ref_annotation} \\
        ${args} \\
        --output ref.isoforms.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        isocall: \$(${isocall_bin} --version 2>&1 | head -1 || echo 'unknown')
    END_VERSIONS
    """
}
