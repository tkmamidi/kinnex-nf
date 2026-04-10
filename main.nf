#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Kinnex IsoSeq Pipeline
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PacBio Kinnex/MAS-Seq IsoSeq analysis pipeline
    - Segmentation (skera split)
    - Demultiplexing (lima)
    - IsoSeq processing (refine, cluster, align, collapse)
    - Isoform classification (pigeon)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { SKERA_SPLIT } from './modules/local/skera_split'
include { LIMA        } from './modules/local/lima'
include { ISOSEQ      } from './subworkflows/isoseq'
include { PIGEON      } from './subworkflows/pigeon'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def validateParams() {
    // Check required parameters
    if (!params.input) {
        error "ERROR: 'input' parameter is required. Please provide a samplesheet TSV."
    }
    if (!params.mas8_primers && !params.skip_segmentation) {
        error "ERROR: 'mas8_primers' parameter is required for segmentation."
    }
    if (!params.isoseq_primers) {
        error "ERROR: 'isoseq_primers' parameter is required."
    }

    // Resolve genome references
    def genome_fasta = params.ref_genome ?: params.genomes[params.genome]?.fasta
    def genome_gtf   = params.ref_annotation ?: params.genomes[params.genome]?.gtf

    if (!genome_fasta) {
        error "ERROR: Reference genome FASTA not found. Provide --ref_genome or valid --genome key."
    }
    if (!genome_gtf && !params.skip_pigeon) {
        error "ERROR: Reference annotation GTF not found. Provide --ref_annotation or valid --genome key."
    }

    return [fasta: genome_fasta, gtf: genome_gtf]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PARSE SAMPLESHEET
    TSV format (no header): POOL_NAME <tab> HIFI_BAM_LOCATION <tab> LIMA_CSV_LOCATION
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def parseSamplesheet(samplesheet) {
    Channel
        .fromPath(samplesheet)
        .splitText()
        .map { line ->
            def fields = line.trim().split('\t')
            if (fields.size() < 3) {
                error "ERROR: Samplesheet must have 3 tab-separated columns: POOL_NAME, HIFI_BAM_LOCATION, LIMA_CSV_LOCATION"
            }

            def pool_name = fields[0]
            def hifi_bam  = fields[1]
            def lima_csv  = fields[2]

            def meta = [
                pool: pool_name
            ]

            return [ meta, file(hifi_bam), file(lima_csv) ]
        }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {
    // Validate parameters and get resolved references
    def refs = validateParams()

    // Create reference channels
    ch_ref_genome     = Channel.fromPath(refs.fasta, checkIfExists: true).collect()
    ch_ref_genome_fai = Channel.fromPath("${refs.fasta}.fai", checkIfExists: true).collect()
    ch_ref_annotation = refs.gtf ? Channel.fromPath(refs.gtf, checkIfExists: true).collect() : Channel.empty()
    ch_ref_annotation_pgi = refs.gtf ? Channel.fromPath("${refs.gtf}.pgi", checkIfExists: true).collect() : Channel.empty()
    ch_mas8_primers   = params.mas8_primers ? Channel.fromPath(params.mas8_primers, checkIfExists: true).collect() : Channel.empty()
    ch_isoseq_primers = Channel.fromPath(params.isoseq_primers, checkIfExists: true).collect()

    // Parse samplesheet (TSV: POOL_NAME, HIFI_BAM, LIMA_CSV)
    ch_input = parseSamplesheet(params.input)

    // Separate channels
    ch_pool_bam  = ch_input.map { meta, bam, lima_csv -> [ meta, bam ] }
    ch_lima_csv  = ch_input.map { meta, bam, lima_csv -> [ meta, lima_csv ] }

    // Store versions
    ch_versions = Channel.empty()

    /*
     * STEP 1: SEGMENTATION (skera split)
     */
    if (!params.skip_segmentation) {
        SKERA_SPLIT(
            ch_pool_bam,
            ch_mas8_primers
        )
        ch_segmented_bam = SKERA_SPLIT.out.bam
        ch_versions = ch_versions.mix(SKERA_SPLIT.out.versions)
    } else {
        // If skipping segmentation, assume input BAMs are already segmented
        ch_segmented_bam = ch_pool_bam
    }

    /*
     * STEP 2: DEMULTIPLEXING (lima)
     */
    // Join segmented BAM with lima CSV
    ch_lima_input = ch_segmented_bam
        .join(ch_lima_csv)
        .map { meta, bam, lima_csv -> [ meta, bam, lima_csv ] }

    LIMA(
        ch_lima_input.map { meta, bam, lima_csv -> [ meta, bam ] },
        ch_isoseq_primers,
        ch_lima_input.map { meta, bam, lima_csv -> lima_csv }
    )
    ch_versions = ch_versions.mix(LIMA.out.versions)

    /*
     * STEP 3: SPLIT LIMA OUTPUT BY SAMPLE
     * Lima outputs multiple BAM files (one per barcode)
     * We need to match them with sample names from lima CSV
     */
    // Flatten lima BAM output and extract barcode from filename
    ch_lima_bam_flat = LIMA.out.bam
        .transpose()  // Flatten the list of BAMs
        .map { meta, bam ->
            // Extract barcode from filename (e.g., pool.lima.bc1001--bc1001.bam)
            def filename = bam.getName()
            def matcher = filename =~ /\.lima\.([^.]+)\.bam$/
            def barcode = matcher ? matcher[0][1] : null

            return [ meta, barcode, bam ]
        }
        .filter { meta, barcode, bam -> barcode != null }

    // Parse lima CSVs to get barcode -> sample mapping
    // Lima CSV format: Barcode,Bio Sample (with header)
    ch_barcode_sample = ch_lima_csv
        .flatMap { meta, csv ->
            def samples = []
            def lines = csv.readLines()
            // Skip header line
            lines.drop(1).each { line ->
                def fields = line.split(',')
                if (fields.size() >= 2) {
                    def barcode = fields[0].trim()
                    def sample  = fields[1].trim()
                    samples << [ meta.pool, barcode, sample ]
                }
            }
            return samples
        }

    // Join lima BAMs with sample names
    ch_sample_bam = ch_lima_bam_flat
        .map { meta, barcode, bam -> [ meta.pool, barcode, meta, bam ] }
        .combine(ch_barcode_sample, by: [0, 1])  // Join by pool and barcode
        .map { pool, barcode, meta, bam, sample ->
            def sample_meta = [
                pool: pool,
                barcode: barcode,
                sample: sample
            ]
            return [ sample_meta, bam ]
        }

    /*
     * STEP 4: ISOSEQ PROCESSING (per sample)
     */
    ISOSEQ(
        ch_sample_bam,
        ch_isoseq_primers,
        ch_ref_genome
    )
    ch_versions = ch_versions.mix(ISOSEQ.out.versions)

    /*
     * STEP 5: PIGEON CLASSIFICATION (per sample)
     */
    if (!params.skip_pigeon) {
        PIGEON(
            ISOSEQ.out.collapsed_gff,
            ISOSEQ.out.flnc_count,
            ch_ref_annotation,
            ch_ref_annotation_pgi,
            ch_ref_genome,
            ch_ref_genome_fai
        )
        ch_versions = ch_versions.mix(PIGEON.out.versions)
    }

    /*
     * COLLECT VERSIONS
     */
    ch_versions
        .collectFile(name: 'versions.yml', storeDir: "${params.outdir}/pipeline_info")
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION HANDLER
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    println ""
    println "Pipeline completed at: ${workflow.complete}"
    println "Execution status: ${workflow.success ? 'OK' : 'FAILED'}"
    println "Duration: ${workflow.duration}"
    println "Output directory: ${params.outdir}"
    println ""
}

workflow.onError {
    println ""
    println "Pipeline execution stopped with error: ${workflow.errorMessage}"
    println ""
}
