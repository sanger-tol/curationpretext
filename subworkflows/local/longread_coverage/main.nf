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
    dot_genome          // Channel: [ val(meta), [  path( datafile )  ] ]
    reads_path          // Channel: [ val(meta),       path( str )      ]

    main:
    ch_versions             = Channel.empty()

    //
    // LOGIC: TAKE THE READ FOLDER AS INPUT AND GENERATE THE CHANNEL OF READ FILES
    //
    ch_reads_path = reads_path.flatMap { meta, dir ->
        files(dir.resolve('*.fasta.gz'), checkIfExists: true, type: 'file' )
            .collect{ fasta -> tuple( meta, fasta ) }
    }


    //
    // PROCESS: MINIMAP ALIGNMENT
    //
    MINIMAP2_ALIGN (
            ch_reads_path,
            reference_tuple.collect(),
            true,
            "csi",
            false,
            false,
    )
    ch_versions         = ch_versions.mix(MINIMAP2_ALIGN.out.versions)

    //
    // LOGIC: COLLECT THE MAPPED BAMS AS THERE MAY BE MULTIPLE AND MERGE, CREATE SAMPLE ID BASED ON PREFIX OF FILE
    //
    MINIMAP2_ALIGN.out.bam
        .collect{ _meta, bam -> bam }
        .map { bams ->
            tuple (
                [ id    : bams.first().name.split('_').first() ], // Change sample ID
                bams
            )
        }
        .set { collected_files_for_merge }


    //
    // MODULE: MERGES THE BAM FILES IN REGARDS TO THE REFERENCE
    //         EMITS A MERGED BAM
    SAMTOOLS_MERGE(
        collected_files_for_merge,
        reference_tuple,
        [[],[]]
    )
    ch_versions         = ch_versions.mix(SAMTOOLS_MERGE.out.versions)


    //
    // MODULE: SORT MAPPED BAM
    //
    SAMTOOLS_SORT (
        SAMTOOLS_MERGE.out.bam,
        [[],[]]
    )
    ch_versions         = ch_versions.mix( SAMTOOLS_SORT.out.versions )


    //
    // MODULE: EXTRACT READS FOR PRIMARY ASSEMBLY
    //
    SAMTOOLS_VIEW_FILTER_PRIMARY(
        SAMTOOLS_SORT.out.bam.map { meta, bam -> tuple( meta + [sz: bam.size(), single_end: true], bam, [] ) },
        reference_tuple.collect(),
        [],
        "csi"
    )
    ch_versions         = ch_versions.mix(SAMTOOLS_VIEW_FILTER_PRIMARY.out.versions)


    //
    // MODULE: BAM TO PRIMARY BED
    //
    BEDTOOLS_BAMTOBED(
        SAMTOOLS_VIEW_FILTER_PRIMARY.out.bam
    )
    ch_versions         = ch_versions.mix(BEDTOOLS_BAMTOBED.out.versions)


    //
    // LOGIC: PREPARING Genome2Cov INPUT
    //
    BEDTOOLS_BAMTOBED.out.bed
        .combine( dot_genome )
        .multiMap { meta, file, my_genome_meta, my_genome ->
            input_tuple         :   tuple (
                                        [   id          :   meta.id,
                                            single_end  :   true    ],
                                        file,
                                        1
                                    )
            dot_genome          :   my_genome
            file_suffix         :   'bed'
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
    ch_versions         = ch_versions.mix( BEDTOOLS_GENOMECOV.out.versions )


    //
    // MODULE: SORT THE PRIMARY BED FILE
    //
    GNU_SORT(
        BEDTOOLS_GENOMECOV.out.genomecov
    )
    ch_versions         = ch_versions.mix( GNU_SORT.out.versions )


    //
    // LOGIC: PREPARING NORMAL COVERAGE INPUT
    //
    GNU_SORT.out.sorted
        .combine( dot_genome )
        .combine( reference_tuple )
        .multiMap { meta, file, meta_my_genome, my_genome, ref_meta, ref ->
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
    ch_versions         = ch_versions.mix( UCSC_BEDGRAPHTOBIGWIG.out.versions )

    emit:
    ch_bigwig           = UCSC_BEDGRAPHTOBIGWIG.out.bigwig
    versions            = ch_versions
}
