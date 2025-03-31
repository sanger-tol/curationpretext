#!/usr/bin/env nextflow

//
// MODULE IMPORT BLOCK
//
include { GAP_FINDER                        } from '../gap_finder/main'
include { TELO_FINDER                       } from '../telo_finder/main'
include { REPEAT_DENSITY                    } from '../repeat_density/main'
include { LONGREAD_COVERAGE                 } from '../longread_coverage/main'

include { GAWK as GAWK_GENERATE_GENOME_FILE } from '../../../modules/nf-core/gawk/main'
include { GET_LARGEST_SCAFFOLD              } from '../../../modules/local/get/largest_scaffold/main'
include { SAMTOOLS_FAIDX                    } from '../../../modules/nf-core/samtools/faidx/main'

workflow ACCESSORY_FILES {
    take:
    reference_tuple
    longread_reads
    val_teloseq

    main:
    ch_versions         = Channel.empty()

    //
    // MODULE: GENERATE INDEX OF REFERENCE
    //          EMITS REFERENCE INDEX FILE
    //
    SAMTOOLS_FAIDX ( reference_tuple, [[],[]] )
    ch_versions     = ch_versions.mix(SAMTOOLS_FAIDX.out.versions)

    //
    // MODULE: TRIMS INDEX INTO A GENOME DESCRIPTION FILE
    //         EMITS REFERENCE GEOME FILE AND REFERENCE INDEX FILE
    GAWK_GENERATE_GENOME_FILE (
        SAMTOOLS_FAIDX.out.fai,
        [],
        false
    )
    ch_versions     = ch_versions.mix( GAWK_GENERATE_GENOME_FILE.out.versions )

    //
    // MODULE: Cut out the largest scaffold size and use as comparator against 512MB
    //          This is the cut off for TABIX using tbi indexes
    //
    GET_LARGEST_SCAFFOLD ( GAWK_GENERATE_GENOME_FILE.out.output ) // Could replace with a native function
    ch_versions     = ch_versions.mix( GET_LARGEST_SCAFFOLD.out.versions )

    //
    // SUBWORKFLOW: GENERATES A GAP.BED FILE TO ID THE LOCATIONS OF GAPS
    //
    GAP_FINDER (
        reference_tuple,
        GET_LARGEST_SCAFFOLD.out.scaff_size.map{it -> it[1].toInteger()}
    )
    ch_versions = ch_versions.mix(GAP_FINDER.out.versions)

    //
    // SUBWORKFLOW: GENERATE TELOMERE WINDOW FILES WITH LONGREAD READS AND REFERENCE
    //
    TELO_FINDER (
        GET_LARGEST_SCAFFOLD.out.scaff_size.map{it -> it[1].toInteger()},
        reference_tuple,
        val_teloseq
    )
    ch_versions = ch_versions.mix(TELO_FINDER.out.versions)

    //
    // SUBWORKFLOW: GENERATES A BIGWIG FOR A REPEAT DENSITY TRACK
    //
    REPEAT_DENSITY (
        reference_tuple,
        GAWK_GENERATE_GENOME_FILE.out.output
    )
    ch_versions = ch_versions.mix(REPEAT_DENSITY.out.versions)

    //
    // SUBWORKFLOW: Takes reference, longread reads
    //
    LONGREAD_COVERAGE (
        reference_tuple,
        SAMTOOLS_FAIDX.out.fai,
        GAWK_GENERATE_GENOME_FILE.out.output,
        longread_reads
    )
    ch_versions = ch_versions.mix(LONGREAD_COVERAGE.out.versions)


    emit:
    gap_file            = GAP_FINDER.out.gap_file
    repeat_file         = REPEAT_DENSITY.out.repeat_density
    telo_file           = TELO_FINDER.out.bedgraph_file
    repeat_file         = REPEAT_DENSITY.out.repeat_density
    coverage_bw         = LONGREAD_COVERAGE.out.ch_bigwig
    mins_bed            = LONGREAD_COVERAGE.out.ch_minbed
    half_bed            = LONGREAD_COVERAGE.out.ch_halfbed
    maxs_bed            = LONGREAD_COVERAGE.out.ch_maxbed
    versions            = ch_versions
}
