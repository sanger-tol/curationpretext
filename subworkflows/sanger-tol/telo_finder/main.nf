//
// MODULE IMPORT BLOCK
//
include { TELOMERE_FINDTELOMERE } from '../../../modules/sanger-tol/telomere/findtelomere/main'
include { HTSLIB_BGZIPTABIX     } from '../../../modules/nf-core/htslib/bgziptabix/main'


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

    TELOMERE_FINDTELOMERE(ch_joined, val_split_telomere)

    ch_windows_for_zip = val_split_telomere
        ? TELOMERE_FINDTELOMERE.out.windows_fwd.mix(TELOMERE_FINDTELOMERE.out.windows_rev)
        : TELOMERE_FINDTELOMERE.out.windows_all

    if (val_zip_bed) {
        ch_beds_windows_for_zip_raw = TELOMERE_FINDTELOMERE.out.telomere_bed_fwd
            .mix(TELOMERE_FINDTELOMERE.out.telomere_bed_rev)
            .mix(ch_windows_for_zip)

        /*
         * Optional outputs normally omit emissions when a glob matches nothing. When a glob yields
         * multiple paths, `item` may be a list — HTSLIB_BGZIPTABIX expects one path per channel element,
         * so expand to (meta, path) tuples.
         */
        ch_beds_windows_for_zip = ch_beds_windows_for_zip_raw
            .flatMap { meta, item ->
                def items = (item instanceof List) ? item : [ item ]
                items.collect { file -> tuple(meta, file, [], []) }
            }

        HTSLIB_BGZIPTABIX(
            ch_beds_windows_for_zip,
            'compress',
            true,
            ''
        )

        ch_gz_index = HTSLIB_BGZIPTABIX.out.output
            .combine(HTSLIB_BGZIPTABIX.out.index)
            .filter { _meta, gz, _meta2, idx -> idx.name.startsWith(gz.name) }
            .map { meta, gz, _meta2, idx -> tuple(meta, gz, idx) }

    } else {
        ch_gz_index = channel.empty()
    }


    emit:
    telomere         = TELOMERE_FINDTELOMERE.out.telomere
    telomere_bed_fwd = TELOMERE_FINDTELOMERE.out.telomere_bed_fwd
    telomere_bed_rev = TELOMERE_FINDTELOMERE.out.telomere_bed_rev
    windows_all      = TELOMERE_FINDTELOMERE.out.windows_all
    windows_fwd      = TELOMERE_FINDTELOMERE.out.windows_fwd
    windows_rev      = TELOMERE_FINDTELOMERE.out.windows_rev
    gz_index         = ch_gz_index

}
