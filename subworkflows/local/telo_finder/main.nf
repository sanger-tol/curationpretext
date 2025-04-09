#!/usr/bin/env nextflow

//
// MODULE IMPORT BLOCK
//
include { FIND_TELOMERE_REGIONS         } from '../../../modules/local/find/telomere_regions/main'
include { GAWK as GAWK_CLEAN_TELOMERE   } from '../../../modules/nf-core/gawk/main'
include { FIND_TELOMERE_WINDOWS         } from '../../../modules/local/find/telomere_windows/main'
include { EXTRACT_TELOMERE              } from '../../../modules/local/extract/telomere/main'

workflow TELO_FINDER {

    take:
    max_scaff_size      // val(size of largest scaffold in bp)
    reference_tuple     // Channel [ val(meta), path(fasta) ]
    teloseq

    main:
    ch_versions     = Channel.empty()

    //
    // MODULE: FINDS THE TELOMERIC SEQEUNCE IN REFERENCE
    //
    FIND_TELOMERE_REGIONS (
        reference_tuple,
        teloseq
    )
    ch_versions     = ch_versions.mix( FIND_TELOMERE_REGIONS.out.versions )


    //
    // MODULE: CLEAN THE .TELOMERE FILE IF CONTAINS "you screwed up" ERROR MESSAGE
    //          (LIKELY WHEN USING LOWERCASE LETTERS OR BAD MOTIF)
    //          WORKS BE RETURNING LINES THAT START WITH '>'
    //
    GAWK_CLEAN_TELOMERE (
        FIND_TELOMERE_REGIONS.out.telomere
    )
    ch_versions     = ch_versions.mix( GAWK_CLEAN_TELOMERE.out.versions )


    //
    // MODULE: GENERATES A WINDOWS FILE FROM THE ABOVE
    //
    FIND_TELOMERE_WINDOWS (
        GAWK_CLEAN_TELOMERE.out.output
    )
    ch_versions     = ch_versions.mix( FIND_TELOMERE_WINDOWS.out.versions )

    //
    // MODULE: EXTRACTS THE LOCATION OF TELOMERIC SEQUENCE BASED ON THE WINDOWS
    //
    EXTRACT_TELOMERE (
        FIND_TELOMERE_WINDOWS.out.windows
    )
    ch_versions     = ch_versions.mix( EXTRACT_TELOMERE.out.versions )

    emit:
    bedgraph_file   = EXTRACT_TELOMERE.out.bed
    bedgraph_file   = EXTRACT_TELOMERE.out.bedgraph
    versions        = ch_versions
}
