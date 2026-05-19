//
// MODULE IMPORT BLOCK
//
include { FINDTELOMERE    } from '../../../modules/sanger-tol/telomere/findtelomere/main'
include { TABIX_BGZIPTABIX } from '../../../modules/nf-core/tabix/bgziptabix/main'


workflow TELO_FINDER {

    take:
    ch_reference           // Channel [ val(meta), path(fasta) ]
    ch_telomereseq         // Channel [ val(meta), val(telomere_motif) ]
    val_split_telomere     // bool
    val_zip_bed            // bool — bgzip + tabix strand *.telomere.bed and windows outputs

    main:

    ch_joined = ch_reference
        .combine(ch_telomereseq, by: 0)
        .map { meta, reference, telomereseq -> tuple(meta, reference, telomereseq) }

    FINDTELOMERE(ch_joined, val_split_telomere)

    ch_windows_for_zip = val_split_telomere
        ? FINDTELOMERE.out.windows_fwd.mix(FINDTELOMERE.out.windows_rev)
        : FINDTELOMERE.out.windows_all

    if (val_zip_bed) {
        ch_beds_windows_for_zip_raw = FINDTELOMERE.out.telomere_bed_fwd
            .mix(FINDTELOMERE.out.telomere_bed_rev)
            .mix(ch_windows_for_zip)

        /*
         * Optional outputs normally omit emissions when a glob matches nothing. When a glob yields
         * multiple paths, `item` may be a list — TABIX_BGZIPTABIX expects one path per channel element,
         * so expand to (meta, path) tuples.
         */
        ch_beds_windows_for_zip = ch_beds_windows_for_zip_raw
            .flatMap { meta, item ->
                def items = (item instanceof List) ? item : [ item ]
                items.collect { file -> tuple(meta, file) }
            }

        TABIX_BGZIPTABIX(ch_beds_windows_for_zip)
    }

    emit:
    telomere         = FINDTELOMERE.out.telomere
    telomere_bed_fwd = FINDTELOMERE.out.telomere_bed_fwd
    telomere_bed_rev = FINDTELOMERE.out.telomere_bed_rev
    windows_all      = FINDTELOMERE.out.windows_all
    windows_fwd      = FINDTELOMERE.out.windows_fwd
    windows_rev      = FINDTELOMERE.out.windows_rev
    gz_index         = val_zip_bed ? TABIX_BGZIPTABIX.out.gz_index : Channel.empty()

}
