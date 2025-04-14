#!/usr/bin/env nextflow

//
// MODULE IMPORT BLOCK
//

include { SAMTOOLS_FAIDX                            } from '../../../modules/nf-core/samtools/faidx/main'
include { PRETEXTMAP as PRETEXTMAP_STANDRD          } from '../../../modules/nf-core/pretextmap/main'
include { PRETEXTMAP as PRETEXTMAP_HIGHRES          } from '../../../modules/nf-core/pretextmap/main'
include { PRETEXTSNAPSHOT as SNAPSHOT_SRES          } from '../../../modules/nf-core/pretextsnapshot/main'
include { PRETEXTSNAPSHOT as SNAPSHOT_HRES          } from '../../../modules/nf-core/pretextsnapshot/main'
include { BAMTOBED_SORT                             } from '../../../modules/local/bamtobed/sort/main.nf'
include { CRAM_GENERATE_CSV                         } from '../../../modules/local/cram/generate_csv/main'

include { HIC_MINIMAP2                              } from '../../../subworkflows/local/hic_minimap2/main'
include { HIC_BWAMEM2                               } from '../../../subworkflows/local/hic_bwamem2/main'

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
    // MODULE: generate a cram csv file containing the required parametres for CRAM_FILTER_ALIGN_BWAMEM2_FIXMATE_SORT
    //
    CRAM_GENERATE_CSV (
        hic_reads_path
    )
    ch_versions         = ch_versions.mix( CRAM_GENERATE_CSV.out.versions )


    //
    // SUBWORKFLOW: mapping hic reads using minimap2
    //
    reference_tuple.view{"MAPPING!: $it"}
    HIC_MINIMAP2 (
        reference_tuple.filter{ meta, _fasta -> meta.aligner == 'minimap2' },
        CRAM_GENERATE_CSV.out.csv,
        SAMTOOLS_FAIDX.out.fai
    )
    ch_versions             = ch_versions.mix( HIC_MINIMAP2.out.versions )


    //
    // SUBWORKFLOW: mapping hic reads using bwamem2
    //
    HIC_BWAMEM2 (
        reference_tuple.filter{ meta, _fasta -> meta.aligner == 'bwamem2' },
        CRAM_GENERATE_CSV.out.csv,
        SAMTOOLS_FAIDX.out.fai
    )
    ch_versions             = ch_versions.mix( HIC_BWAMEM2.out.versions )


    ch_aligned_bams         = HIC_MINIMAP2.out.mergedbam.mix( HIC_BWAMEM2.out.mergedbam )
        .map{ meta, bam ->
            tuple(
                meta + [ sz: bam.size() ],
                bam
            )
        }


    //
    // MODULE: GENERATE PRETEXT MAP FROM MAPPED BAM FOR LOW RES
    //
    PRETEXTMAP_STANDRD (
        ch_aligned_bams,
        reference_tuple.join( SAMTOOLS_FAIDX.out.fai ).collect()
    )
    ch_versions             = ch_versions.mix( PRETEXTMAP_STANDRD.out.versions )

    PRETEXTMAP_HIGHRES (
        ch_aligned_bams,
        reference_tuple.join( SAMTOOLS_FAIDX.out.fai ).collect()
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
    versions                = ch_versions

}
