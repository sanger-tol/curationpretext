#!/usr/bin/env nextflow

// This subworkflow takes an input fasta sequence and csv style list of hic cram file to return
// alignment files including .mcool, pretext and .hic.
// Input - Assembled genomic fasta file, cram file directory
// Output - .mcool, .pretext, .hic

//
// MODULE IMPORT BLOCK
//
include { BWAMEM2_INDEX                                   } from '../../modules/nf-core/bwamem2/index/main'
include { CRAM_FILTER_ALIGN_BWAMEM2_FIXMATE_SORT          } from '../../modules/local/cram_filter_align_bwamem2_fixmate_sort'
include { SAMTOOLS_MERGE                                  } from '../../modules/nf-core/samtools/merge/main'

workflow HIC_BWAMEM2 {
    take:
    reference_tuple     // Channel: tuple [ val(meta), path( fasta ) ]
    csv_ch              // Channel: tuple [ val(meta), path( cram_csv ) ]
    reference_index     // Channel: tuple [ val(meta), path( fai ) ]
    bwa_index           // Channel: tuple [ val(meta), path( index, type: dir ) ]

    main:
    ch_versions             = Channel.empty()
    mappedbam_ch            = Channel.empty()

    // csv_ch
    //     .splitCsv() // tuple ( [meta], [cram, crai, from, to, basename, chunkid, rglines ])
    //     .combine ( reference_tuple )
    //     .combine ( bwa_index )
    //     .map{ cram_id, cram_info, ref_id, ref_dir, bwa_id, bwa_path ->
    //         tuple([
    //                 id: cram_id.id
    //                 ],
    //             file(cram_info[0]),
    //             cram_info[1],
    //             cram_info[2],
    //             cram_info[3],
    //             cram_info[4],
    //             cram_info[5],
    //             cram_info[6],
    //             bwa_path.toString() + '/' + ref_dir.toString().split('/')[-1],
    //             ref_dir
    //         )
    // }
    // .set { ch_filtering_input }

    //
    // MODULE: map hic reads by 10,000 container per time using bwamem2
    //
    CRAM_FILTER_ALIGN_BWAMEM2_FIXMATE_SORT (
        csv_ch.splitCsv().map{ tuple -> tuple.flatten() }, // ch_filtering_input
        bwa_index.collect()
    )
    ch_versions             = ch_versions.mix( CRAM_FILTER_ALIGN_BWAMEM2_FIXMATE_SORT.out.versions )
    mappedbam_ch            = CRAM_FILTER_ALIGN_BWAMEM2_FIXMATE_SORT.out.mappedbam

    //
    // LOGIC: PREPARING BAMS FOR MERGE
    //
    mappedbam_ch
        .map { meta, mbam -> tuple( meta.subMap('id'), mbam ) } // Is this necessary?
        .groupTuple()
        // .map{ meta, file ->
        //     tuple( file )
        // }
        // .collect()
        // .map { file ->
        //     tuple (
        //         [
        //         id: file[0].toString().split('/')[-1].split('_')[0] + '_' + file[0].toString().split('/')[-1].split('_')[1]
        //         ],
        //         file
        //     )
        // }
        .set { collected_files_for_merge }

    //
    // MODULE: MERGE POSITION SORTED BAM FILES AND MARK DUPLICATES
    //
    SAMTOOLS_MERGE (
        collected_files_for_merge,
        reference_tuple,
        reference_index
    )
    ch_versions             = ch_versions.mix ( SAMTOOLS_MERGE.out.versions.first() )


    emit:
    mergedbam               = SAMTOOLS_MERGE.out.bam
    versions                = ch_versions
}
