//
// GENERATE BED FILE OF GAPS AND LENGTH IN REFERENCE
//

include { SEQTK_CUTN        } from '../../../modules/nf-core/seqtk/cutn/main'
include { GAWK              } from '../../../modules/nf-core/gawk/main'
include { TABIX_BGZIPTABIX  } from '../../../modules/nf-core/tabix/bgziptabix/main'

workflow GAP_FINDER {
    take:
    ch_reference     // Channel [ val(meta), path(fasta) ]
    val_run_bgzip    // val(boolean)

    main:

    //
    // MODULE: GENERATES A GAP SUMMARY FILE
    //
    SEQTK_CUTN (
        ch_reference
    )


    //
    // MODULE: ADD THE LENGTH OF GAP TO BED FILE - INPUT FOR PRETEXT MODULE
    //
    GAWK (
        SEQTK_CUTN.out.bed,
        [],
        false
    )


    //
    // MODULE: BGZIP AND TABIX THE GAP FILE
    //
    TABIX_BGZIPTABIX (
        SEQTK_CUTN.out.bed.filter{ meta, file -> val_run_bgzip}
    )

    emit:
    gap_file        = GAWK.out.output
    gap_tabix       = TABIX_BGZIPTABIX.out.gz_index
}
