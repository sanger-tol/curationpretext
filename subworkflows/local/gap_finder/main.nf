#!/usr/bin/env nextflow

//
// MODULE IMPORT BLOCK
//
include { SEQTK_CUTN                } from '../../../modules/nf-core/seqtk/cutn/main'
include { GAWK as GAWK_GAP_LENGTH   } from '../../../modules/nf-core/gawk/main'

workflow GAP_FINDER {
    take:
    reference_tuple     // Channel [ val(meta), path(fasta) ]

    main:

    //
    // MODULE: GENERATES A GAP SUMMARY FILE
    //
    SEQTK_CUTN (
        reference_tuple
    )


    //
    // MODULE: ADD THE LENGTH OF GAP TO BED FILE - INPUT FOR PRETEXT MODULE
    //
    GAWK_GAP_LENGTH (
        SEQTK_CUTN.out.bed,
        [],
        false
    )

    emit:
    gap_file        = GAWK_GAP_LENGTH.out.output
}
