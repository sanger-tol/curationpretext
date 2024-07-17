#!/usr/bin/env nextflow

//
// MODULE IMPORT BLOCK
//
include { GAP_FINDER            } from './gap_finder'
include { TELO_FINDER           } from './telo_finder'
include { REPEAT_DENSITY        } from './repeat_density'
include { LONGREAD_COVERAGE     } from './longread_coverage'

include { GENERATE_GENOME_FILE  } from '../../modules/local/generate_genome_file'
include { GET_LARGEST_SCAFF     } from '../../modules/local/get_largest_scaff'

include { SAMTOOLS_FAIDX        } from '../../modules/nf-core/samtools/faidx/main'

workflow ACCESSORY_FILES {
    take:
    reference_tuple
    longread_reads

    main:
    ch_versions         = Channel.empty()

    //
    // MODULE: GENERATE INDEX OF REFERENCE
    //          EMITS REFERENCE INDEX FILE
    //
    SAMTOOLS_FAIDX ( reference_tuple, [[],[]] )
    ch_versions     = ch_versions.mix(SAMTOOLS_FAIDX.out.versions)

    //
    // MODULE: TRIMS INDEX INTO A GENOME DESCRIPTION FILE
    //         EMITS REFERENCE GEOME FILE AND REFERENCE INDEX FILE
    GENERATE_GENOME_FILE ( SAMTOOLS_FAIDX.out.fai )
    ch_versions     = ch_versions.mix( GENERATE_GENOME_FILE.out.versions )

    //
    // MODULE: Cut out the largest scaffold size and use as comparator against 512MB
    //          This is the cut off for TABIX using tbi indexes
    //
    GET_LARGEST_SCAFF ( GENERATE_GENOME_FILE.out.dotgenome )
    ch_versions     = ch_versions.mix( GET_LARGEST_SCAFF.out.versions )

    //
    // SUBWORKFLOW: GENERATES A GAP.BED FILE TO ID THE LOCATIONS OF GAPS
    //
    GAP_FINDER (
        reference_tuple,
        GET_LARGEST_SCAFF.out.scaff_size.map{it -> it[0].toInteger()}
    )
    ch_versions = ch_versions.mix(GAP_FINDER.out.versions)

    //
    // SUBWORKFLOW: GENERATE TELOMERE WINDOW FILES WITH LONGREAD READS AND REFERENCE
    //
    TELO_FINDER (
        GET_LARGEST_SCAFF.out.scaff_size.map{it -> it[0].toInteger()},
        reference_tuple,
        params.teloseq
    )
    ch_versions = ch_versions.mix(TELO_FINDER.out.versions)

    //
    // SUBWORKFLOW: GENERATES A BIGWIG FOR A REPEAT DENSITY TRACK
    //
    REPEAT_DENSITY (
        reference_tuple,
        GENERATE_GENOME_FILE.out.dotgenome
    )
    ch_versions = ch_versions.mix(REPEAT_DENSITY.out.versions)

    //
    // SUBWORKFLOW: Takes reference, longread reads
    //
    LONGREAD_COVERAGE (
        reference_tuple,
        SAMTOOLS_FAIDX.out.fai,
        GENERATE_GENOME_FILE.out.dotgenome,
        longread_reads
    )
    ch_versions = ch_versions.mix(LONGREAD_COVERAGE.out.versions)


    emit:
    gap_file            = GAP_FINDER.out.gap_file
    repeat_file         = REPEAT_DENSITY.out.repeat_density
    telo_file           = TELO_FINDER.out.bedgraph_file
    repeat_file         = REPEAT_DENSITY.out.repeat_density
    coverage_bw         = LONGREAD_COVERAGE.out.ch_bigwig
    coverage_avg_bw     = LONGREAD_COVERAGE.out.ch_bigwig_avg
    coverage_log_bw     = LONGREAD_COVERAGE.out.ch_bigwig_log
    mins_bed            = LONGREAD_COVERAGE.out.ch_minbed
    half_bed            = LONGREAD_COVERAGE.out.ch_halfbed
    maxs_bed            = LONGREAD_COVERAGE.out.ch_maxbed
    versions            = ch_versions.ifEmpty(null)
}