#!/usr/bin/env nextflow

//
// MODULE IMPORT BLOCK
//
include { SEQTK_CUTN                } from '../../../modules/nf-core/seqtk/cutn/main'
include { GAWK as GAWK_GAP_LENGTH   } from '../../../modules/nf-core/gawk/main'
include { TABIX_BGZIPTABIX          } from '../../../modules/nf-core/tabix/bgziptabix/main'

workflow GAP_FINDER {
    take:
    reference_tuple     // Channel [ val(meta), path(fasta) ]
    max_scaff_size      // val(size of largest scaffold in bp)

    main:
    ch_versions     = Channel.empty()

    //
    // MODULE: GENERATES A GAP SUMMARY FILE
    //
    SEQTK_CUTN (
        reference_tuple
    )
    ch_versions     = ch_versions.mix( SEQTK_CUTN.out.versions )

    //
    // MODULE: ADD THE LENGTH OF GAP TO BED FILE - INPUT FOR PRETEXT MODULE
    //
    GAWK_GAP_LENGTH (
        SEQTK_CUTN.out.bed,
        [],
        false
    )
    ch_versions     = ch_versions.mix( GAWK_GAP_LENGTH.out.versions )

    emit:
    gap_file        = GAWK_GAP_LENGTH.out.output
    versions        = ch_versions
}
