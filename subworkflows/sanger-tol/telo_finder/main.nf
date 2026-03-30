//
// MODULE IMPORT BLOCK
//
include { BIOAWK                        } from '../../../modules/nf-core/bioawk/main'
include { TELOMERE_REGIONS              } from '../../../modules/sanger-tol/telomere/regions/main'
include { GAWK as GAWK_SPLIT_TELOMERE   } from '../../../modules/nf-core/gawk/main'
include { TELOMERE_WINDOWS              } from '../../../modules/sanger-tol/telomere/windows/main'
include { TELOMERE_EXTRACT              } from '../../../modules/sanger-tol/telomere/extract/main'
include { TABIX_BGZIPTABIX              } from '../../../modules/nf-core/tabix/bgziptabix'


workflow TELO_FINDER {

    take:
    ch_reference        // Channel [ val(meta), path(fasta) ]
    ch_telomereseq      // Channel [ val(meta), path(fasta) ]
    val_split_telomere  // bool
    val_run_bgzip       // bool

    main:

    // NOTE: BIOAWK PROGRAM TO RETURN A TAB DELIMITED FILE CONTAINING:
    //       corrected_sequence  G_count  G_percentage  reversed?  original_sequence
    ch_bioawk_program = channel.of('''\
        BEGIN { OFS = "\\t" } {
            sequence = toupper($seq);
            copy_seq = sequence;
            g_count = gsub(/G/, "", sequence);
            g_percent = 100*g_count/length(copy_seq);
            rev = (g_percent > 30);
            final_sequence = rev ? revcomp($seq) : $seq;
            printf "%s\\t%d\\t%.2f\\t%s\\t%s\\n", final_sequence, g_count, g_percent, (rev ? "true" : "false"), copy_seq
        }'''.stripIndent())
        .collectFile(name: "bioawk_getdata.awk", cache: true)
        .collect()


    //
    // MODULE: BIOAWK CONVERT THE MOTIF INTO THE 5 PRIME DIRECTION
    //         IF PROVIDED IN THE 3 PRIME DIRECTION
    //         IF MOTIF HAS A G CONTENT OF > 30% IT IS IN THE 3 PRIME
    //
    BIOAWK(
        ch_telomereseq,
        ch_bioawk_program,
        false,
        "tsv"
    )


    //
    // LOGIC: READ LINES OF THE OUTPUT FILE
    //        RETURN THE FIRST SEGMENT OF LINE "corrected_sequence"
    //
    ch_corrected_telomere = BIOAWK.out.output
        .map { meta, file ->
            def lines = file.toFile().readLines()
            tuple(meta, lines[0].split('\t')[0])
        }


    // NOTE: COMBINE CHANNELS TO ENSURE TELOMERE IS FOR X REFERENCE
    matched_channels = ch_reference
        .combine(ch_corrected_telomere, by: 0)
        .multiMap { meta, ref, telomere ->
            reference_ch: [meta, ref]
            telomere_ch: telomere
        }


    //
    // MODULE: FINDS THE TELOMERIC SEQEUNCE IN REFERENCE
    //
    TELOMERE_REGIONS (
        matched_channels.reference_ch,
        matched_channels.telomere_ch
    )


    // NOTE: TAG THE DIRECTION OF THE TELOMERE AS 0 == WHOLE DATASET
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
    //         THIS ONLY HAPPENS ON WHOLE TELOMERIC FILES
    //
    TELOMERE_WINDOWS (
        ch_regions_for_extraction.filter { meta, _file -> meta.direction == 0 }
    )

    //
    // LOGIC: MIX THE FILES FROM THE TWO CHANNELS
    //        REMOVE WHOLE TELOMERE FROM THE UNVALIDATED TRACK ALSO
    //        OUTPUT CAN HAVE SIZE 0 WHICH BREAKS gawk IN EXTRACT
    //        FILTER OUT THE 0 SIZE FILES
    //
    ch_final_telomere_files = ch_regions_for_extraction
        .filter { meta, _file -> meta.direction != 0 }
        .mix(TELOMERE_WINDOWS.out.windows)
        .filter { _meta, file ->
            file.size() > 0
        }


    //
    // MODULE: EXTRACT TELOMERE DATA FROM FIND_TELOMERE
    //         AND REFORMAT INTO BEDGRAPH FILE
    //
    TELOMERE_EXTRACT(
        ch_final_telomere_files
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
        ch_telo_bedfiles.filter{ _meta, _file -> val_run_bgzip}
    )

    emit:
    telomere_summary    = BIOAWK.out.output             // Channel [meta, tsv]
    bed_file            = ch_telo_bedfiles              // Channel [meta, bed]
    bed_gz_tbi          = TABIX_BGZIPTABIX.out.gz_index // Channel [meta, index]
    bedgraph_file       = ch_telo_bedgraphs             // Channel [meta, [bedfiles]] - Used in pretext_graph

}
