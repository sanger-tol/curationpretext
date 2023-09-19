#!/usr/bin/env nextflow

//
// MODULE IMPORT BLOCK
//

include { BAMTOBED_SORT                             } from '../../modules/local/bamtobed_sort.nf'
include { GENERATE_CRAM_CSV                         } from '../../modules/local/generate_cram_csv'
include { CRAM_FILTER_ALIGN_BWAMEM2_FIXMATE_SORT    } from '../../modules/local/cram_filter_align_bwamem2_fixmate_sort'

include { BWAMEM2_INDEX                             } from '../../modules/nf-core/bwamem2/index/main'
include { SAMTOOLS_MERGE                            } from '../../modules/nf-core/samtools/merge/main'
include { SAMTOOLS_FAIDX                            } from '../../modules/nf-core/samtools/faidx/main'
include { PRETEXTMAP as PRETEXTMAP_STANDRD          } from '../../modules/nf-core/pretextmap/main'
include { PRETEXTMAP as PRETEXTMAP_HIGHRES          } from '../../modules/nf-core/pretextmap/main'
include { PRETEXTSNAPSHOT as SNAPSHOT_SRES          } from '../../modules/nf-core/pretextsnapshot/main'
include { PRETEXTSNAPSHOT as SNAPSHOT_HRES          } from '../../modules/nf-core/pretextsnapshot/main'


workflow GENERATE_MAPS {
    take:
    reference_tuple     // Channel [ val(meta), path(file) ]
    hic_reads_path      // Channel [ path(directory) ]

    main:
    ch_versions         = Channel.empty()

    //
    // MODULE: GENERATE INDEX OF REFERENCE FASTA
    //
    SAMTOOLS_FAIDX (
        reference_tuple,
        [[],[]]
    )
    ch_versions         = ch_versions.mix(SAMTOOLS_FAIDX.out.versions)


    //
    // MODULE: Indexing on reference output the folder of indexing files
    //
    BWAMEM2_INDEX (
        reference_tuple
    )
    ch_versions         = ch_versions.mix(BWAMEM2_INDEX.out.versions)

    Channel.of([[id: 'hic_path'], hic_reads_path]).set { ch_hic_path }

    //
    // MODULE: generate a cram csv file containing the required parametres for CRAM_FILTER_ALIGN_BWAMEM2_FIXMATE_SORT
    //
    GENERATE_CRAM_CSV (
        ch_hic_path
    )
    ch_versions         = ch_versions.mix(GENERATE_CRAM_CSV.out.versions)

    //
    // LOGIC: organise all parametres into a channel for CRAM_FILTER_ALIGN_BWAMEM2_FIXMATE_SORT
    //
    GENERATE_CRAM_CSV.out.csv
        .splitCsv()
        .combine (reference_tuple)
        .combine (BWAMEM2_INDEX.out.index)
        .map{ cram_id, cram_info, ref_id, ref_dir, bwa_id, bwa_path ->
            tuple(  [
                    id: cram_id.id
                    ],
                    file(cram_info[0]),
                    cram_info[1],
                    cram_info[2],
                    cram_info[3],
                    cram_info[4],
                    cram_info[5],
                    cram_info[6],
                    bwa_path.toString() + '/' + ref_dir.toString().split('/')[-1]
            )
        }
       .set { ch_filtering_input }

    //
    // MODULE: parallel proccessing bwa-mem2 alignment by given interval of containers from cram files
    //
    CRAM_FILTER_ALIGN_BWAMEM2_FIXMATE_SORT (
        ch_filtering_input
    )
    ch_versions         = ch_versions.mix(CRAM_FILTER_ALIGN_BWAMEM2_FIXMATE_SORT.out.versions)

    //
    // LOGIC: PREPARING BAMS FOR MERGE
    //
    CRAM_FILTER_ALIGN_BWAMEM2_FIXMATE_SORT.out.mappedbam
        .map{ meta, file ->
            tuple( file )
        }
        .collect()
        .map { file ->
            tuple (
                [
                id: file[0].toString().split('/')[-1].split('_')[0]  // Change to sample_id
                ],
                file
            )
        }
        .set { collected_files_for_merge }


    //
    // MODULE: MERGE POSITION SORTED BAM FILES AND MARK DUPLICATES
    //
    SAMTOOLS_MERGE (
        collected_files_for_merge,
        reference_tuple,
        SAMTOOLS_FAIDX.out.fai
    )
    ch_versions         = ch_versions.mix ( SAMTOOLS_MERGE.out.versions )

    //
    // LOGIC: PREPARING PRETEXT MAP INPUT
    //
    SAMTOOLS_MERGE.out.bam
        .combine( reference_tuple )
        .multiMap { bam_meta, bam, ref_meta, ref_fa ->
            input_bam:  tuple(bam_meta, bam)
            reference:  ref_fa
        }
        .set { pretext_input }

    //
    // MODULE: GENERATE PRETEXT MAP FROM MAPPED BAM FOR LOW RES
    //
    PRETEXTMAP_STANDRD (
        pretext_input.input_bam,
        pretext_input.reference
    )
    ch_versions         = ch_versions.mix(PRETEXTMAP_STANDRD.out.versions)

    //
    // LOGIC: HIRES IS TOO INTENSIVE FOR RUNNING IN GITHUB CI SO THIS STOPS IT RUNNING
    //
    if ( params.config_profile_name ) {
        config_profile_name = params.config_profile_name
    } else {
        config_profile_name = 'Local'
    }

    if ( !config_profile_name.contains('GitHub') ) {
        //
        // MODULE: GENERATE PRETEXT MAP FROM MAPPED BAM FOR HIGH RES
        //
        PRETEXTMAP_HIGHRES (
            pretext_input.input_bam,
            pretext_input.reference
        )
        ch_versions         = ch_versions.mix( PRETEXTMAP_HIGHRES.out.versions )
    }

    //
    // MODULE: GENERATE PNG FROM STANDARD PRETEXT
    //
    SNAPSHOT_SRES (
        PRETEXTMAP_STANDRD.out.pretext
    )
    ch_versions         = ch_versions.mix(SNAPSHOT_SRES.out.versions)

    // NOTE: SNAPSHOT HRES IS TEMPORARILY REMOVED DUE TO ISSUES WITH MEMORY
    //
    // MODULE: GENERATE PNG FROM HIRES PRETEXT
    //
    //SNAPSHOT_HRES (
    //    PRETEXTMAP_HIGHRES.out.pretext
    //)
    //ch_versions         = ch_versions.mix(SNAPSHOT_HRES.out.versions)

    emit:
    standrd_pretext     = PRETEXTMAP_STANDRD.out.pretext
    standrd_snpshot     = SNAPSHOT_SRES.out.image
    //highres_pretext     = PRETEXTMAP_HIGHRES.out.pretext
    //highres_snpshot     = SNAPSHOT_HRES.out.image
    versions            = ch_versions.ifEmpty(null)

}
