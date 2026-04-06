process CLAIR3_RNA {
    tag "$meta.sample"
    label 'process_high'

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
    # Resolve symlinks to absolute paths (required by Clair3-RNA Docker)
    BAM_ABS=\$(readlink -f ${mapped_bam})
    BAI_ABS=\$(readlink -f ${mapped_bai})
    REF_ABS=\$(readlink -f ${ref_genome})
    FAI_ABS=\$(readlink -f ${ref_genome_fai})
    BAM_DIR=\$(dirname \${BAM_ABS})
    REF_DIR=\$(dirname \${REF_ABS})

    # Capture version before main run
    CLAIR3_RNA_VERSION=\$(docker run --rm hkubal/clair3-rna:latest \\
        /opt/bin/run_clair3_rna --version 2>&1 | head -1 || echo 'unknown')

    # Build mount args (deduplicate if BAM and REF share a directory)
    if [ "\${BAM_DIR}" = "\${REF_DIR}" ]; then
        MOUNT_ARGS="-v \${BAM_DIR}:\${BAM_DIR}:ro"
    else
        MOUNT_ARGS="-v \${BAM_DIR}:\${BAM_DIR}:ro -v \${REF_DIR}:\${REF_DIR}:ro"
    fi

    docker run --rm \\
        --user "\$(id -u):\$(id -g)" \\
        -w \${PWD} \\
        -v \${PWD}:\${PWD} \\
        \${MOUNT_ARGS} \\
        hkubal/clair3-rna:latest \\
        /opt/bin/run_clair3_rna \\
        --bam_fn \${BAM_ABS} \\
        --ref_fn \${REF_ABS} \\
        --output_dir "${prefix}_clair3_rna" \\
        --threads ${task.cpus} \\
        --platform ${platform} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        clair3-rna: \${CLAIR3_RNA_VERSION}
    END_VERSIONS
    """
}
