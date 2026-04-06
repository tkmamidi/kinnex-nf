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
    # Gzip the GTF if not already compressed (isocall requires gzipped input)
    if [[ "${ref_annotation}" == *.gz ]]; then
        GTF_GZ="${ref_annotation}"
    else
        gzip -c ${ref_annotation} > ${ref_annotation}.gz
        GTF_GZ="${ref_annotation}.gz"
    fi

    "${isocall_bin}" prep-isoforms \\
        --gtf \${GTF_GZ} \\
        ${args} \\
        --output ref.isoforms.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        isocall: \$("${isocall_bin}" --version 2>&1 | head -1 || echo 'unknown')
    END_VERSIONS
    """
}
