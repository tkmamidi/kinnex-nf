/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IsoSeq Subworkflow - refine, cluster, align, collapse
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { ISOSEQ_REFINE   } from '../modules/local/isoseq_refine'
include { ISOSEQ_CLUSTER  } from '../modules/local/isoseq_cluster'
include { PBMM2_ALIGN     } from '../modules/local/pbmm2_align'
include { ISOSEQ_COLLAPSE } from '../modules/local/isoseq_collapse'

workflow ISOSEQ {
    take:
    ch_lima_bam      // channel: [ val(meta), path(bam) ]
    ch_primers       // channel: path(primers)
    ch_ref_genome    // channel: path(ref_genome)

    main:
    ch_versions = Channel.empty()

    // Step 1: Refine - remove poly(A) tails and concatemers
    ISOSEQ_REFINE(
        ch_lima_bam,
        ch_primers
    )
    ch_versions = ch_versions.mix(ISOSEQ_REFINE.out.versions)

    // Step 2: Cluster reads
    ISOSEQ_CLUSTER(
        ISOSEQ_REFINE.out.bam
    )
    ch_versions = ch_versions.mix(ISOSEQ_CLUSTER.out.versions)

    // Step 3: Align to reference genome
    PBMM2_ALIGN(
        ISOSEQ_CLUSTER.out.bam,
        ch_ref_genome
    )
    ch_versions = ch_versions.mix(PBMM2_ALIGN.out.versions)

    // Step 4: Collapse into unique isoforms
    // Combine mapped bam with flnc bam and pbi for collapse
    ch_collapse_input = PBMM2_ALIGN.out.bam
        .join(ISOSEQ_REFINE.out.bam)
        .join(ISOSEQ_REFINE.out.pbi)
        .map { meta, mapped_bam, flnc_bam, flnc_pbi ->
            [ meta, mapped_bam, flnc_bam, flnc_pbi ]
        }

    ISOSEQ_COLLAPSE(
        ch_collapse_input
    )
    ch_versions = ch_versions.mix(ISOSEQ_COLLAPSE.out.versions)

    emit:
    flnc_bam       = ISOSEQ_REFINE.out.bam         // channel: [ val(meta), path(bam) ]
    clustered_bam  = ISOSEQ_CLUSTER.out.bam        // channel: [ val(meta), path(bam) ]
    mapped_bam     = PBMM2_ALIGN.out.bam           // channel: [ val(meta), path(bam) ]
    mapped_bai     = PBMM2_ALIGN.out.bai           // channel: [ val(meta), path(bai) ]
    collapsed_gff  = ISOSEQ_COLLAPSE.out.gff       // channel: [ val(meta), path(gff) ]
    flnc_count     = ISOSEQ_COLLAPSE.out.flnc_count // channel: [ val(meta), path(txt) ]
    versions       = ch_versions                    // channel: path(versions.yml)
}
