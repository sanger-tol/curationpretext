#!/usr/bin/env nextflow

//
// MODULE IMPORT BLOCK
//

include { BAMTOBED_SORT                             } from '../../modules/local/bamtobed_sort.nf'
include { GENERATE_CRAM_CSV                         } from '../../modules/local/generate_cram_csv'
include { BWAMEM2_INDEX                             } from '../../modules/nf-core/bwamem2/index/main'
include { SAMTOOLS_FAIDX                            } from '../../modules/nf-core/samtools/faidx/main'
include { PRETEXTMAP as PRETEXTMAP_STANDRD          } from '../../modules/nf-core/pretextmap/main'
include { PRETEXTMAP as PRETEXTMAP_HIGHRES          } from '../../modules/nf-core/pretextmap/main'
include { PRETEXTSNAPSHOT as SNAPSHOT_SRES          } from '../../modules/nf-core/pretextsnapshot/main'
include { PRETEXTSNAPSHOT as SNAPSHOT_HRES          } from '../../modules/nf-core/pretextsnapshot/main'
include { HIC_MINIMAP2                              } from '../../subworkflows/local/hic_minimap2'
include { HIC_BWAMEM2                               } from '../../subworkflows/local/hic_bwamem2'

workflow GENERATE_MAPS {
    take:
    reference_tuple     // Channel [ val(meta), path(file)      ]
    hic_reads_path      // Channel [ val(meta), path(directory) ]


    main:
    ch_versions         = Channel.empty()

    //
    // MODULE: GENERATE INDEX OF REFERENCE FASTA
    //
    SAMTOOLS_FAIDX (
        reference_tuple,
        [[],[]]
    )
    ch_versions         = ch_versions.mix( SAMTOOLS_FAIDX.out.versions )

    //
    // MODULE: Indexing on reference output the folder of indexing files
    //
    BWAMEM2_INDEX (
        reference_tuple
    )
    ch_versions         = ch_versions.mix( BWAMEM2_INDEX.out.versions )

    //
    // MODULE: generate a cram csv file containing the required parametres for CRAM_FILTER_ALIGN_BWAMEM2_FIXMATE_SORT
    //
    GENERATE_CRAM_CSV (
        hic_reads_path
    )
    ch_versions         = ch_versions.mix( GENERATE_CRAM_CSV.out.versions )

    GENERATE_CRAM_CSV.out.csv.view()

    //
    // LOGIC: make branches for different hic aligner.
    //
    hic_reads_path
        .combine( reference_tuple )
        .map{ meta, hic_read_path, ref_meta, ref ->
            tuple(
                [   id:         ref_meta.id,
                    aligner:    ref_meta.aligner
                ],
                ref
            )
        }
        .branch {
            minimap2:           it[0].aligner == "minimap2"
            bwamem2:            it[0].aligner == "bwamem2"
        }
        .set{ ch_aligner }

    //
    // SUBWORKFLOW: mapping hic reads using minimap2
    //
    HIC_MINIMAP2 (
        ch_aligner.minimap2,
        GENERATE_CRAM_CSV.out.csv,
        SAMTOOLS_FAIDX.out.fai
    )
    ch_versions             = ch_versions.mix( HIC_MINIMAP2.out.versions )
    mergedbam               = HIC_MINIMAP2.out.mergedbam

    //
    // SUBWORKFLOW: mapping hic reads using bwamem2
    //
    HIC_BWAMEM2 (
        ch_aligner.bwamem2,
        GENERATE_CRAM_CSV.out.csv,
        SAMTOOLS_FAIDX.out.fai,
        BWAMEM2_INDEX.out.index
    )
    ch_versions             = ch_versions.mix( HIC_BWAMEM2.out.versions )
    mergedbam               = HIC_BWAMEM2.out.mergedbam

    //
    // LOGIC: PREPARING PRETEXT MAP INPUT
    //
    mergedbam
        .combine( reference_tuple )
        .combine( SAMTOOLS_FAIDX.out.fai )
        .multiMap { bam_meta, bam, ref_meta, ref_fa, fai_meta, fai ->
            input_bam:  tuple(
                            [   id: ref_meta.id,
                                sz: file( bam ).size()
                            ],
                            bam
                        )
            reference:  tuple( ref_meta, ref_fa, fai )
        }
        .set { pretext_input }

    //
    // MODULE: GENERATE PRETEXT MAP FROM MAPPED BAM FOR LOW RES
    //
    PRETEXTMAP_STANDRD (
        pretext_input.input_bam,
        pretext_input.reference
    )
    ch_versions             = ch_versions.mix( PRETEXTMAP_STANDRD.out.versions )

    PRETEXTMAP_HIGHRES (
        pretext_input.input_bam,
        pretext_input.reference
    )
    ch_versions             = ch_versions.mix( PRETEXTMAP_HIGHRES.out.versions )

    //
    // MODULE: GENERATE PNG FROM STANDARD PRETEXT
    //
    SNAPSHOT_SRES (
        PRETEXTMAP_STANDRD.out.pretext
    )
    ch_versions             = ch_versions.mix( SNAPSHOT_SRES.out.versions )

    emit:
    standrd_pretext         = PRETEXTMAP_STANDRD.out.pretext
    standrd_snpshot         = SNAPSHOT_SRES.out.image
    highres_pretext         = PRETEXTMAP_HIGHRES.out.pretext
    versions                = ch_versions.ifEmpty(null)

}
