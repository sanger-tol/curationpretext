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
    val_skip_tracks     // val(csv_list)
    ch_reference_sizes  // Channel [ val(meta), path(file)   ]


    main:
    ch_empty_file       = channel.fromPath("${baseDir}/assets/EMPTY.txt")

    //
    // NOTE: THIS IS DUPLICATED IN THE CURATIONPRETEXT WORKFLOW
    //
    dont_generate_tracks  = val_skip_tracks ? val_skip_tracks.split(",") : "NONE"


    //
    // SUBWORKFLOW: GENERATES A GAP.BED FILE TO ID THE LOCATIONS OF GAPS
    //
    if (dont_generate_tracks.contains("gap") || dont_generate_tracks.contains("ALL")) {
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
    if (dont_generate_tracks.contains("telo") || dont_generate_tracks.contains("ALL")) {
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
    if (dont_generate_tracks.contains("repeats") || dont_generate_tracks.contains("ALL")) {
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
    if (dont_generate_tracks.contains("coverage") || dont_generate_tracks.contains("ALL"))  {
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
