#!/usr/bin/env nextflow

//
// MODULE IMPORT BLOCK
//
include { BEDTOOLS_INTERSECT                } from '../../../modules/nf-core/bedtools/intersect/main'
include { BEDTOOLS_MAKEWINDOWS              } from '../../../modules/nf-core/bedtools/makewindows/main'
include { BEDTOOLS_MAP                      } from '../../../modules/nf-core/bedtools/map/main'
include { UCSC_BEDGRAPHTOBIGWIG             } from '../../../modules/nf-core/ucsc/bedgraphtobigwig/main'
include { GNU_SORT as GNU_SORT_A            } from '../../../modules/nf-core/gnu/sort/main'
include { GNU_SORT as GNU_SORT_B            } from '../../../modules/nf-core/gnu/sort/main'
include { GNU_SORT as GNU_SORT_C            } from '../../../modules/nf-core/gnu/sort/main'
include { GAWK as GAWK_RENAME_IDS           } from '../../../modules/nf-core/gawk/main'
include { GAWK as GAWK_REPLACE_DOTS         } from '../../../modules/nf-core/gawk/main'
include { GAWK as GAWK_REFORMAT_INTERSECT   } from '../../../modules/nf-core/gawk/main'
include { TABIX_BGZIPTABIX                  } from '../../../modules/nf-core/tabix/bgziptabix'


workflow FEATURE_DENSITY {
    take:
    intervals_file
    ch_chrom_sizes

    main:
    //
    // MODULE: CREATE WINDOWS FROM .GENOME FILE
    //
    BEDTOOLS_MAKEWINDOWS(
        ch_chrom_sizes
    )

    //
    // LOGIC: COMBINE TWO CHANNELS AND OUTPUT tuple(meta, windows_file, repeat_file)
    //
    BEDTOOLS_MAKEWINDOWS.out.bed
        .combine( intervals_file )
        .map{ meta, windows_file, _repeat_meta, repeat_file ->
                    tuple (
                        meta,
                        windows_file,
                        repeat_file
                    )
        }
        .set { intervals }

    //
    // MODULE: GENERATES THE DENSITY FILE FROM THE WINDOW FILE AND GENOME FILE
    //
    BEDTOOLS_INTERSECT(
        intervals,
        ch_chrom_sizes
    )

    //
    // MODULE: FIXES IDS FOR FILE
    //
    ch_rename_ids_awk = channel.of('''\
        BEGIN { }
        {
            gsub(/\\./, "0")
            print
        }'''.stripIndent())
        .collectFile(name: "rename_ids.awk", cache: true)
        .collect()

    GAWK_RENAME_IDS(
        BEDTOOLS_INTERSECT.out.intersect,
        ch_rename_ids_awk,
        false
    )

    //
    // MODULE: SORTS THE ABOVE BED FILES
    //
    GNU_SORT_A (
        GAWK_RENAME_IDS.out.output      // Intersect file
    )

    GNU_SORT_B (
        ch_chrom_sizes                  // Genome file - Will not run unless genome file is sorted to
    )

    GNU_SORT_C (
        BEDTOOLS_MAKEWINDOWS.out.bed    // Windows file
    )

    //
    // MODULE: ADDS 4TH COLUMN TO BED FILE USED IN THE DENSITY GRAPH
    //
    ch_reformat_intersect_awk = channel.of('''\
        function my_abs(x) {
            return x < 0 ? -x : x
        }
        {
            gsub(/\\./, "0")
            printf "%s\\t%.0f\\n", $0, my_abs($3 - $2)
        }'''.stripIndent())
        .collectFile(name: "reformat_intersect.awk", cache: true)
        .collect()

    GAWK_REFORMAT_INTERSECT (
        GNU_SORT_A.out.sorted,
        ch_reformat_intersect_awk,
        false
    )

    //
    // MODULE: TABIX AND GZIP THE DENSITY BED FILE
    //
    TABIX_BGZIPTABIX (
        GAWK_REFORMAT_INTERSECT.out.output
    )

    //
    // LOGIC: COMBINES THE REFORMATTED INTERSECT FILE AND WINDOWS FILE CHANNELS AND SORTS INTO
    //        tuple(intersect_meta, windows file, intersect file)
    //
    GAWK_REFORMAT_INTERSECT.out.output
        .combine( GNU_SORT_C.out.sorted )
        .map{ intersect_meta, bed, _sorted_meta, windows_file ->
                    tuple (
                        intersect_meta,
                        windows_file,
                        bed
                    )
        }
        .set { for_mapping }

    //
    // MODULE: MAPS THE REPEATS AGAINST THE REFERENCE GENOME
    //
    BEDTOOLS_MAP(
        for_mapping,
        GNU_SORT_B.out.sorted
    )

    //
    // MODULE: REPLACES . WITH 0 IN MAPPED FILE
    //
    ch_replace_dots_awk = channel.of('''\
        {
            gsub(/\\./, "0")
            print
        }'''.stripIndent())
        .collectFile(name: "replace_dots.awk", cache: true)
        .collect()

    GAWK_REPLACE_DOTS (
        BEDTOOLS_MAP.out.mapped,
        ch_replace_dots_awk,
        false
    )

    //
    // MODULE: CONVERTS GENOME FILE AND BED INTO A BIGWIG FILE
    //
    UCSC_BEDGRAPHTOBIGWIG(
        GAWK_REPLACE_DOTS.out.output,
        GNU_SORT_B.out.sorted.map { _meta, file -> file } // Pulls file from tuple of meta and file
    )

    emit:
    density_file    = UCSC_BEDGRAPHTOBIGWIG.out.bigwig
    density_tabix   = TABIX_BGZIPTABIX.out.gz_index
}
