//
// MODULE IMPORT BLOCK
//
include { TELOMERE_REGIONS              } from '../../../modules/sanger-tol/telomere/regions/main'
include { GAWK as GAWK_SPLIT_TELOMERE   } from '../../../modules/nf-core/gawk/main'
include { TELOMERE_WINDOWS              } from '../../../modules/sanger-tol/telomere/windows/main'
include { TELOMERE_EXTRACT              } from '../../../modules/sanger-tol/telomere/extract/main'
include { TABIX_BGZIPTABIX              } from '../../../modules/nf-core/tabix/bgziptabix'


workflow TELO_FINDER {

    take:
    ch_reference        // Channel [ val(meta), path(fasta) ]
    ch_telomereseq      // Channel.of( telomere sequence )
    val_split_telomere  // bool
    val_run_bgzip       // bool

    main:

    //
    // MODULE: FINDS THE TELOMERIC SEQEUNCE IN REFERENCE
    //
    TELOMERE_REGIONS (
        ch_reference,
        ch_telomereseq
    )

    ch_full_telomere = TELOMERE_REGIONS.out.telomere
        .map{ meta, file ->
            def new_meta = meta + [direction: 0]
            [new_meta, file]
        }

    //
    // MODULE: SPLIT THE TELOMERE FILE INTO 5' and 3' FILES
    //
    if (val_split_telomere) {

        ch_split_telomere = channel.of('''\
            BEGIN {
                FS="\\t"; OFS="\\t"
            } {
                print > "direction."$3".telomere"
            }'''.stripIndent())
            .collectFile(name: "split_telomere.awk", cache: true)
            .collect()

        GAWK_SPLIT_TELOMERE (
            ch_full_telomere,
            ch_split_telomere,
            true
        )

        //
        // LOGIC: COLLECT FILES AND ITERATE THROUGH
        //          ADD DIRECTION BASED ON:
        //              0: FULL TELOMERE FILE
        //              3: FOR 3Prime DIRECTION
        //              5: For 5Prime DIRECTION
        //          THIS PRODUCES A TRIO OF CHANNELS: [meta], file
        //          FILTER FOR SIZE > 0 FOR SAFETY
        //
        ch_regions_for_extraction = GAWK_SPLIT_TELOMERE.out.output
            .flatMap { meta, files ->
                files
                    .findAll { file -> file.size() > 0 }
                    .collect { file ->
                        if (file.name.contains("direction.0")) {
                            [meta + [direction: 5], file]
                        } else if (file.name.contains("direction.1")) {
                            [meta + [direction: 3], file]
                        } else {
                            error("Unexpected file name pattern in TELOMERE_REGIONS split output: ${file.name}")
                        }
                    }
            }
            .mix(ch_full_telomere)


    } else {
        ch_regions_for_extraction  = ch_full_telomere
    }


    //
    // MODULE: GENERATES A WINDOWS FILE FROM THE ABOVE
    //
    TELOMERE_WINDOWS (
        ch_regions_for_extraction
    )


    //
    // LOGIC: OUTPUT CAN HAVE SIZE 0 WHICH BREAKS gawk IN EXTRACT
    //        FILTER OUT THE 0 SIZE FILES
    //
    ch_filtered_windows_for_extraction = TELOMERE_WINDOWS.out.windows
        .filter { _meta, file ->
            file.size() > 0
        }

    //
    // MODULE: EXTRACT TELOMERE DATA FROM FIND_TELOMERE
    //         AND REFORMAT INTO BEDGRAPH FILE
    //
    TELOMERE_EXTRACT(
        ch_filtered_windows_for_extraction
    )


    //
    // LOGIC: CLEAN OUTPUT CHANNEL INTO
    //        [meta, [bedgraph_list]]
    //
    ch_telo_bedgraphs = TELOMERE_EXTRACT.out.bedgraph
        .map { meta, bedgraph ->
            [ meta - meta.subMap("direction"), bedgraph ]
        }
        .groupTuple(by: 0)
        .map { meta, bedgraphs -> [ meta, bedgraphs.sort { file -> file.name } ] }

    ch_telo_bedfiles = TELOMERE_EXTRACT.out.bed
        .map { meta, bed ->
            [ meta - meta.subMap("direction"), bed ]
        }

    //
    // MODULE: BGZIP AND TABIX THE TELO BED FILES
    //
    TABIX_BGZIPTABIX (
        ch_telo_bedfiles.filter{ meta, file -> val_run_bgzip}
    )

    emit:
    bed_file        = ch_telo_bedfiles          // Channel [meta, bed]
    bed_gz_tbi      = TABIX_BGZIPTABIX.out.gz_index  // Not used anymore
    bedgraph_file   = ch_telo_bedgraphs         // Channel [meta, [bedfiles]] - Used in pretext_graph

}
