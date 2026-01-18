/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Pigeon Subworkflow - prepare, classify, filter, report
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { PIGEON_PREPARE  } from '../modules/local/pigeon_prepare'
include { PIGEON_CLASSIFY } from '../modules/local/pigeon_classify'
include { PIGEON_FILTER   } from '../modules/local/pigeon_filter'
include { PIGEON_REPORT   } from '../modules/local/pigeon_report'

workflow PIGEON {
    take:
    ch_collapsed_gff   // channel: [ val(meta), path(gff) ]
    ch_flnc_count      // channel: [ val(meta), path(txt) ]
    ch_ref_annotation  // channel: path(gtf)
    ch_ref_annotation_pgi  // channel: path(pgi) - pigeon index for annotation
    ch_ref_genome      // channel: path(fasta)
    ch_ref_genome_fai  // channel: path(fai) - FASTA index file

    main:
    ch_versions = Channel.empty()

    // Step 1: Prepare - sort GFF
    PIGEON_PREPARE(
        ch_collapsed_gff
    )
    ch_versions = ch_versions.mix(PIGEON_PREPARE.out.versions)

    // Step 2: Classify isoforms
    // Combine sorted gff with flnc count
    ch_classify_input = PIGEON_PREPARE.out.gff
        .join(ch_flnc_count)
        .map { meta, sorted_gff, flnc_count ->
            [ meta, sorted_gff, flnc_count ]
        }

    PIGEON_CLASSIFY(
        ch_classify_input,
        ch_ref_annotation,
        ch_ref_annotation_pgi,
        ch_ref_genome,
        ch_ref_genome_fai
    )
    ch_versions = ch_versions.mix(PIGEON_CLASSIFY.out.versions)

    // Step 3: Filter classifications
    ch_filter_input = PIGEON_CLASSIFY.out.classification
        .join(PIGEON_CLASSIFY.out.junctions)
        .join(PIGEON_PREPARE.out.gff)
        .map { meta, classification, junctions, sorted_gff ->
            [ meta, classification, junctions, sorted_gff ]
        }

    PIGEON_FILTER(
        ch_filter_input
    )
    ch_versions = ch_versions.mix(PIGEON_FILTER.out.versions)

    // Step 4: Generate saturation report
    // pigeon report takes classification as input and generates saturation.txt as output
    PIGEON_REPORT(
        PIGEON_FILTER.out.filtered_classification
    )
    ch_versions = ch_versions.mix(PIGEON_REPORT.out.versions)

    emit:
    sorted_gff              = PIGEON_PREPARE.out.gff                      // channel: [ val(meta), path(gff) ]
    classification          = PIGEON_CLASSIFY.out.classification          // channel: [ val(meta), path(txt) ]
    junctions               = PIGEON_CLASSIFY.out.junctions               // channel: [ val(meta), path(txt) ]
    filtered_classification = PIGEON_FILTER.out.filtered_classification   // channel: [ val(meta), path(txt) ]
    filter_report           = PIGEON_FILTER.out.report                    // channel: [ val(meta), path(json) ]
    saturation              = PIGEON_REPORT.out.saturation                // channel: [ val(meta), path(txt) ]
    report                  = PIGEON_REPORT.out.report                    // channel: [ val(meta), path(json) ]
    versions                = ch_versions                                  // channel: path(versions.yml)
}
