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
    # Copy all inputs to local scratch — NFS (nfs_t) and FUSE (fusefs_t) mounts
    # cannot be bind-mounted by rootless Podman/crun due to SELinux OCI policy
    SCRATCH_DIR=\$(mktemp -d /scratch/clair3_rna_XXXXXX)
    trap "rm -rf \${SCRATCH_DIR}" EXIT

    cp ${mapped_bam} \${SCRATCH_DIR}/input.bam
    cp ${mapped_bai} \${SCRATCH_DIR}/input.bam.bai
    cp \$(readlink -f ${ref_genome})     \${SCRATCH_DIR}/ref.fasta
    cp \$(readlink -f ${ref_genome_fai}) \${SCRATCH_DIR}/ref.fasta.fai

    # Capture version
    CLAIR3_RNA_VERSION=\$(docker run --rm \
        --userns=keep-id \
        --security-opt label=disable \
        hkubal/clair3-rna:latest \
        /opt/bin/run_clair3_rna --version 2>&1 | head -1 || echo 'unknown')

    # Run with all mounts from local scratch
    docker run --rm \\
        --userns=keep-id \\
        --security-opt label=disable \\
        -w \${SCRATCH_DIR} \\
        -v \${SCRATCH_DIR}:\${SCRATCH_DIR} \\
        hkubal/clair3-rna:latest \\
        /opt/bin/run_clair3_rna \\
        --bam_fn \${SCRATCH_DIR}/input.bam \\
        --ref_fn \${SCRATCH_DIR}/ref.fasta \\
        --output_dir "\${SCRATCH_DIR}/${prefix}_clair3_rna" \\
        --threads ${task.cpus} \\
        --platform ${platform} \\
        ${args}

    # Move results back to Nextflow work dir
    mv "\${SCRATCH_DIR}/${prefix}_clair3_rna" "./"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        clair3-rna: \${CLAIR3_RNA_VERSION}
    END_VERSIONS
    """
}
