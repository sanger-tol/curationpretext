#!/usr/bin/env nextflow

//
// MODULE IMPORT BLOCK
//
include { BEDTOOLS_BAMTOBED                             } from '../../../modules/nf-core/bedtools/bamtobed/main'
include { BEDTOOLS_GENOMECOV                            } from '../../../modules/nf-core/bedtools/genomecov/main'
include { GNU_SORT                                      } from '../../../modules/nf-core/gnu/sort/main'
include { MINIMAP2_ALIGN                                } from '../../../modules/nf-core/minimap2/align/main'
include { SAMTOOLS_MERGE                                } from '../../../modules/nf-core/samtools/merge/main'
include { SAMTOOLS_SORT                                 } from '../../../modules/nf-core/samtools/sort/main'
include { SAMTOOLS_VIEW as SAMTOOLS_VIEW_FILTER_PRIMARY } from '../../../modules/nf-core/samtools/view/main'
include { UCSC_BEDGRAPHTOBIGWIG                         } from '../../../modules/nf-core/ucsc/bedgraphtobigwig/main'


workflow LONGREAD_COVERAGE {

    take:
    reference_tuple     // Channel: [ val(meta), path( reference_file ) ]
    reference_index     // Channel: [ val(meta), path( reference_indx ) ]
    dot_genome          // Channel: [ val(meta), [ path( datafile )   ] ]
    reads_path          // Channel: [ val(meta), [ path( read_files ) ] ]

    main:

    //
    // PROCESS: MINIMAP ALIGNMENT
    //
    reads_path.flatMap{ meta, files ->
        files.collect{ file ->
            tuple(meta, file)
        }
    }
    .set { single_reads_path }

    MINIMAP2_ALIGN (
            single_reads_path,
            reference_tuple.collect(),
            true,
            "csi",
            false,
            false,
    )


    //
    // LOGIC: COLLECT THE MAPPED BAMS AS THERE MAY BE MULTIPLE AND MERGE, CREATE SAMPLE ID BASED ON PREFIX OF FILE
    //
    MINIMAP2_ALIGN.out.bam
        .collect{ _meta, bam -> bam }
        .map { bams ->
            tuple (
                [ id    : bams.first().name.split('_').first() ], // Change sample ID
                bams,
                []
            )
        }
        .set { collected_files_for_merge }


    //
    // MODULE: MERGES THE BAM FILES IN REGARDS TO THE REFERENCE
    //         EMITS A MERGED BAM
    // TODO: I AM PASSING IN AN INDEX, COMBINE AND MAP CHANNEL?
    def ref_and_index = reference_tuple
        .combine(reference_index)
        .map{ meta, reference, _meta2, index ->
            [meta, reference, index, []]
        }

    SAMTOOLS_MERGE(
        collected_files_for_merge,
        ref_and_index
    )


    //
    // MODULE: SORT MAPPED BAM
    //
    SAMTOOLS_SORT (
        SAMTOOLS_MERGE.out.bam,
        [[],[]],
        []
    )


    //
    // MODULE: EXTRACT READS FOR PRIMARY ASSEMBLY
    //
    SAMTOOLS_VIEW_FILTER_PRIMARY(
        SAMTOOLS_SORT.out.bam.map { meta, bam -> tuple( meta + [sz: bam.size(), single_end: true], bam, [] ) },
        reference_tuple.collect().map { meta, file -> [meta, file, []] },
        [],
        "csi"
    )


    //
    // MODULE: BAM TO PRIMARY BED
    //
    BEDTOOLS_BAMTOBED(
        SAMTOOLS_VIEW_FILTER_PRIMARY.out.bam
    )


    //
    // LOGIC: PREPARING Genome2Cov INPUT
    //
    BEDTOOLS_BAMTOBED.out.bed
        .combine( dot_genome )
        .multiMap { meta, file, _my_genome_meta, my_genome ->
            input_tuple     :   tuple (
                                    [   id          :   meta.id,
                                        single_end  :   true    ],
                                    file,
                                    1
                                )
            dot_genome      :   my_genome
            file_suffix     :   'bed'
        }
        .set { genomecov_input }


    //
    // MODULE: GENOME TO COVERAGE BED
    //
    BEDTOOLS_GENOMECOV(
        genomecov_input.input_tuple,
        genomecov_input.dot_genome,
        genomecov_input.file_suffix,
        false
    )


    //
    // MODULE: SORT THE PRIMARY BED FILE
    //
    GNU_SORT(
        BEDTOOLS_GENOMECOV.out.genomecov
    )


    //
    // LOGIC: PREPARING NORMAL COVERAGE INPUT
    //
    GNU_SORT.out.sorted
        .combine( dot_genome )
        .combine( reference_tuple )
        .multiMap { _meta, file, _meta_my_genome, my_genome, ref_meta, _ref ->
            ch_coverage_bed :   tuple (
                                    [   id: ref_meta.id,
                                        single_end: true
                                    ],
                                    file
                                )
            genome_file     :   my_genome
        }
        .set { bed2bw_normal_input }


    //
    // MODULE: CONVERT BEDGRAPH TO BIGWIG
    //
    UCSC_BEDGRAPHTOBIGWIG(
        bed2bw_normal_input.ch_coverage_bed,
        bed2bw_normal_input.genome_file
    )

    emit:
    ch_bigwig           = UCSC_BEDGRAPHTOBIGWIG.out.bigwig
}
