//
// GENERATE BED FILE OF GAPS AND LENGTH IN REFERENCE
//

include { SEQTK_CUTN                } from '../../../modules/nf-core/seqtk/cutn/main'
include { GAWK as GAWK_GAP_LENGTH   } from '../../../modules/nf-core/gawk/main'
include { TABIX_BGZIPTABIX          } from '../../../modules/nf-core/tabix/bgziptabix/main'

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

    ch_reformat_gaps = channel.of('''\
        BEGIN { OFS = "\\t" } {
            print $0, sqrt(($3-$2)*($3-$2))
        }'''.stripIndent())
        .collectFile(name: "reformat_gaps.awk", cache: true)
        .collect()


    //
    // MODULE: ADD THE LENGTH OF GAP TO BED FILE - INPUT FOR PRETEXT MODULE
    //
    GAWK_GAP_LENGTH (
        SEQTK_CUTN.out.bed,
        ch_reformat_gaps,
        false
    )


    //
    // MODULE: BGZIP AND TABIX THE GAP FILE
    //
    TABIX_BGZIPTABIX (
        SEQTK_CUTN.out.bed.filter{ meta, file -> val_run_bgzip}
    )

    emit:
    gap_file        = GAWK_GAP_LENGTH.out.output
    gap_tabix       = TABIX_BGZIPTABIX.out.gz_index
}
