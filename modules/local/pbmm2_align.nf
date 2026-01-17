process PBMM2_ALIGN {
    tag "$meta.sample"
    label 'process_high'

    input:
    tuple val(meta), path(clustered_bam)
    path ref_genome

    output:
    tuple val(meta), path("*.mapped.bam"), emit: bam
    tuple val(meta), path("*.mapped.bam.bai"), emit: bai
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: params.pbmm2_extra_args ?: ''
    def preset = params.pbmm2_preset ?: 'ISOSEQ'
    def prefix = task.ext.prefix ?: "${meta.sample}"
    """
    pbmm2 align \\
        --preset ${preset} \\
        ${args} \\
        ${clustered_bam} \\
        ${ref_genome} \\
        ${prefix}.mapped.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pbmm2: \$(pbmm2 --version 2>&1 | grep -oP 'pbmm2 \\K[\\d.]+' || echo 'unknown')
    END_VERSIONS
    """
}
