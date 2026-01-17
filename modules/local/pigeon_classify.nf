process PIGEON_CLASSIFY {
    tag "$meta.sample"
    label 'process_high'

    input:
    tuple val(meta), path(sorted_gff), path(flnc_count)
    path ref_annotation
    path ref_annotation_pgi  // Pigeon index file for annotation
    path ref_genome
    path ref_genome_fai      // FASTA index file

    output:
    tuple val(meta), path("*_classification.txt"), emit: classification
    tuple val(meta), path("*_junctions.txt"), emit: junctions
    tuple val(meta), path("*_reasons.txt"), emit: reasons, optional: true
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: params.pigeon_classify_extra_args ?: ''
    def prefix = task.ext.prefix ?: "${meta.sample}"
    def fl_arg = flnc_count ? "--fl ${flnc_count}" : ''
    """
    pigeon classify \\
        ${args} \\
        ${sorted_gff} \\
        ${ref_annotation} \\
        ${ref_genome} \\
        ${fl_arg}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        pigeon: \$(pigeon --version 2>&1 | grep -oP 'pigeon \\K[\\d.]+' || echo 'unknown')
    END_VERSIONS
    """
}
