#!/usr/bin/env nextflow

//
// MODULE IMPORT BLOCK
//
include { GAP_FINDER                        } from '../gap_finder/main'
include { TELO_FINDER                       } from '../telo_finder/main'
include { REPEAT_DENSITY                    } from '../repeat_density/main'
include { LONGREAD_COVERAGE                 } from '../longread_coverage/main'

include { GAWK as GAWK_GENERATE_GENOME_FILE } from '../../../modules/nf-core/gawk/main'

workflow ACCESSORY_FILES {
    take:
    reference_tuple
    longread_reads
    val_teloseq
    ch_reference_fai   // Channel [ val(meta), path(file)      ]


    main:
    ch_versions         = Channel.empty()
    ch_empty_file       = Channel.fromPath("${baseDir}/assets/EMPTY.txt")

    //
    // NOTE: THIS IS DUPLICATED IN THE CURATIONPRETEXT WORKFLOW,
    //          PASSING THE PARAM TO THE SUBWORKFLOW CAUSED SOME ISSUES IN TESTING
    //          SO WE USE IT DIRECTLY AGAIN.
    //
    dont_generate_tracks  = params.skip_tracks ? params.skip_tracks.split(",") : "NONE"


    //
    // MODULE: TRIMS INDEX INTO A GENOME DESCRIPTION FILE
    //         EMITS REFERENCE GEOME FILE AND REFERENCE INDEX FILE
    GAWK_GENERATE_GENOME_FILE (
        ch_reference_fai,
        [],
        false
    )
    ch_versions         = ch_versions.mix( GAWK_GENERATE_GENOME_FILE.out.versions )


    //
    // SUBWORKFLOW: GENERATES A GAP.BED FILE TO ID THE LOCATIONS OF GAPS
    //
    if (dont_generate_tracks.contains("gap") || dont_generate_tracks.contains("ALL")) {
        gap_file            = ch_empty_file
    } else {
        GAP_FINDER (
            reference_tuple
        )
        ch_versions         = ch_versions.mix(GAP_FINDER.out.versions)
        gap_file            = GAP_FINDER.out.gap_file.map{ it -> it[1] }
    }


    //
    // SUBWORKFLOW: GENERATE TELOMERE WINDOW FILES WITH LONGREAD READS AND REFERENCE
    //
    if (dont_generate_tracks.contains("telo") || dont_generate_tracks.contains("ALL")) {
        telo_file       = ch_empty_file
    } else {
        TELO_FINDER (
            reference_tuple,
            val_teloseq
        )
        ch_versions     = ch_versions.mix(TELO_FINDER.out.versions)
        telo_file       = TELO_FINDER.out.bedgraph_file
    }


    //
    // SUBWORKFLOW: GENERATES A BIGWIG FOR A REPEAT DENSITY TRACK
    //
    if (dont_generate_tracks.contains("repeats") || dont_generate_tracks.contains("ALL")) {
        repeat_file     = ch_empty_file
    } else {
        REPEAT_DENSITY (
            reference_tuple,
            GAWK_GENERATE_GENOME_FILE.out.output
        )
        ch_versions     = ch_versions.mix(REPEAT_DENSITY.out.versions)
        repeat_file     = REPEAT_DENSITY.out.repeat_density.map{ it -> it[1] }
    }


    //
    // SUBWORKFLOW: Takes reference, longread reads
    //
    if (dont_generate_tracks.contains("coverage") || dont_generate_tracks.contains("ALL"))  {
        longread_output = ch_empty_file
    } else {
        LONGREAD_COVERAGE (
            reference_tuple,
            ch_reference_fai,
            GAWK_GENERATE_GENOME_FILE.out.output,
            longread_reads
        )
        ch_versions     = ch_versions.mix(LONGREAD_COVERAGE.out.versions)
        longread_output = LONGREAD_COVERAGE.out.ch_bigwig.map{ it -> it[1] }
    }

    emit:
    gap_file
    repeat_file
    telo_file           // This is the possible collection of telomere files
    longread_output
    versions            = ch_versions
}
