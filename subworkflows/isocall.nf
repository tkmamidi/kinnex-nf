/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Isocall Subworkflow - prep-isoforms, profile
    (merge and call are left to downstream analysis)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { ISOCALL_PREP    } from '../modules/local/isocall_prep'
include { ISOCALL_PROFILE } from '../modules/local/isocall_profile'

workflow ISOCALL {
    take:
    ch_mapped_bam       // channel: [ val(meta), path(bam) ]
    ch_mapped_bai       // channel: [ val(meta), path(bai) ]
    ch_ref_annotation   // channel: path(gtf)

    main:
    ch_versions = Channel.empty()

    // Step 1: Prepare reference isoforms from GTF (runs once)
    ISOCALL_PREP(
        ch_ref_annotation
    )
    ch_versions = ch_versions.mix(ISOCALL_PREP.out.versions)

    // Step 2: Generate per-sample transcription profiles
    ch_profile_input = ch_mapped_bam
        .join(ch_mapped_bai)

    ISOCALL_PROFILE(
        ch_profile_input
    )
    ch_versions = ch_versions.mix(ISOCALL_PROFILE.out.versions)

    emit:
    isoforms = ISOCALL_PREP.out.isoforms       // channel: path(isoforms.gz)
    profiles = ISOCALL_PROFILE.out.profile      // channel: [ val(meta), path(profile.gz) ]
    versions = ch_versions                       // channel: path(versions.yml)
}
