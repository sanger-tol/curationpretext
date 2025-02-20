#!/usr/bin/env nextflow

//
// MODULE IMPORT BLOCK
//
include { FIND_TELOMERE_REGIONS     } from '../../modules/local/find_telomere_regions'
include { FIND_TELOMERE_WINDOWS     } from '../../modules/local/find_telomere_windows'
include { EXTRACT_TELO              } from '../../modules/local/extract_telo'
include { TABIX_BGZIPTABIX          } from '../../modules/nf-core/tabix/bgziptabix'

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
    // MODULE: GENERATES A WINDOWS FILE FROM THE ABOVE
    //
    FIND_TELOMERE_WINDOWS (
        FIND_TELOMERE_REGIONS.out.telomere
    )
    ch_versions     = ch_versions.mix( FIND_TELOMERE_WINDOWS.out.versions )

    //
    // MODULE: EXTRACTS THE LOCATION OF TELOMERIC SEQUENCE BASED ON THE WINDOWS
    //
    EXTRACT_TELO (
        FIND_TELOMERE_WINDOWS.out.windows
    )
    ch_versions     = ch_versions.mix( EXTRACT_TELO.out.versions )

    emit:
    bedgraph_file   = EXTRACT_TELO.out.bed
    bedgraph_file   = EXTRACT_TELO.out.bedgraph
    versions        = ch_versions
}
