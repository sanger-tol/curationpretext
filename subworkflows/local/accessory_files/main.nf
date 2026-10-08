#!/usr/bin/env nextflow

//
// SANGER_TOL SUBWORKFLOW IMPORT BLOCK
//
include { GAP_FINDER                        } from '../../sanger-tol/gap_finder/main'
include { TELO_FINDER                       } from '../../sanger-tol/telo_finder/main'
include { READ_COVERAGE                     } from '../../sanger-tol/read_coverage/main'
include { REPEAT_DENSITY                    } from '../../sanger-tol/repeat_density/main'

workflow ACCESSORY_FILES {
    take:
    reference_tuple     // Channel [ val(meta), path(file)   ]
    longread_reads      // Channel [ val(meta), [path(file)] ]
    val_teloseq         // val(telomere_sequence)
    val_split_telomere  // val(bool)
    val_run_telomere
    val_run_repeats
    val_run_coverage
    val_run_busco
    val_run_pebble
    val_run_gap
    val_track_indexes
    val_no_tracks
    ch_reference_sizes  // Channel [ val(meta), path(file)   ]


    main:
    ch_empty_file       = channel.fromPath("${baseDir}/assets/EMPTY.txt")

    //
    // SUBWORKFLOW: GENERATES A GAP.BED FILE TO ID THE LOCATIONS OF GAPS
    //
    if (!val_run_gap || val_no_tracks) {
        gap_file            = ch_empty_file
    } else {
        GAP_FINDER (
            reference_tuple,
            false
        )
        gap_file            = GAP_FINDER.out.gap_file.map{ it -> it[1] }
    }


    //
    // SUBWORKFLOW: GENERATE TELOMERE WINDOW FILES WITH LONGREAD READS AND REFERENCE
    //
    if (!val_run_telomere || val_no_tracks) {
        telo_file       = ch_empty_file
    } else {
        TELO_FINDER (
            reference_tuple,
            val_teloseq,
            val_split_telomere,
            false
        )
        telo_file       = TELO_FINDER.out.bedgraph_file
                            .map{ it -> it[1] }
                            .ifEmpty("${baseDir}/assets/EMPTY.txt")
    }


    //
    // SUBWORKFLOW: GENERATES A BIGWIG FOR A REPEAT DENSITY TRACK
    //
    if (!val_run_repeats || val_no_tracks) {
        repeat_file     = ch_empty_file
    } else {
        REPEAT_DENSITY (
            reference_tuple,
            ch_reference_sizes
        )
        repeat_file     = REPEAT_DENSITY.out.repeat_density.map{ it -> it[1] }
    }


    //
    // SUBWORKFLOW: Takes reference, longread reads
    //
    if (!val_run_coverage || val_no_tracks) {
        coverage_output = ch_empty_file
    } else {
        READ_COVERAGE (
            longread_reads,
            reference_tuple,
            ch_reference_sizes.map{ _meta, file -> file }
        )

        coverage_output = READ_COVERAGE.out.bigwig.map{ it -> it[1] }
    }



    emit:
    gap_file
    repeat_file
    telo_file           // This is the possible collection of telomere files
    coverage_output
}
