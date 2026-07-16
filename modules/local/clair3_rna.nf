process CLAIR3_RNA {
    tag "$meta.sample"
    label 'process_high'

    input:
    tuple val(meta), path(mapped_bam), path(mapped_bai)
    path ref_genome
    path ref_genome_fai

    output:
    tuple val(meta), path("*_clair3_rna"), emit: output_dir
    tuple val(meta), path("*_clair3_rna/*.vcf.gz"), emit: vcf
    tuple val(meta), path("*_clair3_rna/*.vcf.gz.tbi"), emit: vcf_tbi, optional: true
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

    # Run with all mounts from local scratch
    docker run --rm \\
        --userns=keep-id \\
        --security-opt label=disable \\
        -w \${SCRATCH_DIR} \\
        -v \${SCRATCH_DIR}:\${SCRATCH_DIR} \\
        hkubal/clair3-rna:v0.2.2 \\
        /opt/bin/run_clair3_rna \\
        --bam_fn \${SCRATCH_DIR}/input.bam \\
        --ref_fn \${SCRATCH_DIR}/ref.fasta \\
        --output_dir "\${SCRATCH_DIR}/${prefix}_clair3_rna" \\
        --threads ${task.cpus} \\
        --platform ${platform} \\
        ${args}

    # Rename clair3 outputs to include sample prefix
    mv "\${SCRATCH_DIR}/${prefix}_clair3_rna/output.vcf.gz" \\
       "\${SCRATCH_DIR}/${prefix}_clair3_rna/${prefix}.vcf.gz"
    if [ -f "\${SCRATCH_DIR}/${prefix}_clair3_rna/output.vcf.gz.tbi" ]; then
        mv "\${SCRATCH_DIR}/${prefix}_clair3_rna/output.vcf.gz.tbi" \\
           "\${SCRATCH_DIR}/${prefix}_clair3_rna/${prefix}.vcf.gz.tbi"
    fi

    # Remove intermediate VCFs (pileup and full_alignment) — final merged VCF is the renamed one
    rm -f "\${SCRATCH_DIR}/${prefix}_clair3_rna/pileup.vcf.gz" \\
          "\${SCRATCH_DIR}/${prefix}_clair3_rna/pileup.vcf.gz.tbi" \\
          "\${SCRATCH_DIR}/${prefix}_clair3_rna/full_alignment.vcf.gz" \\
          "\${SCRATCH_DIR}/${prefix}_clair3_rna/full_alignment.vcf.gz.tbi"

    # Move results back to Nextflow work dir
    mv "\${SCRATCH_DIR}/${prefix}_clair3_rna" "./"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        clair3-rna: "0.2.2"
    END_VERSIONS
    """
}
