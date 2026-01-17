process ISOSEQ_COLLAPSE {
    tag "$meta.sample"
    label 'process_high'

    input:
    tuple val(meta), path(mapped_bam), path(flnc_bam), path(flnc_pbi)

    output:
    tuple val(meta), path("*.collapsed.gff"), emit: gff
    tuple val(meta), path("*.collapsed.flnc_count.txt"), emit: flnc_count
    tuple val(meta), path("*.collapsed.abundance.txt"), emit: abundance, optional: true
    tuple val(meta), path("*.collapsed.group.txt"), emit: group, optional: true
    tuple val(meta), path("*.collapsed.read_stat.txt"), emit: read_stat, optional: true
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: params.isoseq_collapse_extra_args ?: ''
    def prefix = task.ext.prefix ?: "${meta.sample}"
    """
    isoseq collapse \\
        ${args} \\
        ${mapped_bam} \\
        ${flnc_bam} \\
        ${prefix}.collapsed.gff

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        isoseq: \$(isoseq --version 2>&1 | grep -oP 'isoseq \\K[\\d.]+' || echo 'unknown')
    END_VERSIONS
    """
}
