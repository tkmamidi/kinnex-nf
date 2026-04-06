process CLAIR3_RNA {
    tag "$meta.sample"
    label 'process_high'

    container 'docker://hkubal/clair3-rna:latest'

    input:
    tuple val(meta), path(mapped_bam), path(mapped_bai)
    path ref_genome
    path ref_genome_fai

    output:
    tuple val(meta), path("*_clair3_rna"), emit: output_dir
    tuple val(meta), path("*_clair3_rna/output.vcf.gz"), emit: vcf
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: params.clair3_rna_extra_args ?: ''
    def platform = params.clair3_rna_platform ?: 'hifi_mas_pbmm2'
    def prefix = task.ext.prefix ?: "${meta.sample}"
    """
    run_clair3_rna \\
        --bam_fn ${mapped_bam} \\
        --ref_fn ${ref_genome} \\
        --output_dir ${prefix}_clair3_rna \\
        --threads ${task.cpus} \\
        --platform ${platform} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        clair3-rna: \$(run_clair3_rna --version 2>&1 | head -1 || echo 'unknown')
    END_VERSIONS
    """
}
