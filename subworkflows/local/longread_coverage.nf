#!/usr/bin/env nextflow

//
// MODULE IMPORT BLOCK
//
include { BEDTOOLS_BAMTOBED                             } from '../../modules/nf-core/bedtools/bamtobed/main'
include { BEDTOOLS_GENOMECOV                            } from '../../modules/nf-core/bedtools/genomecov/main'
include { BEDTOOLS_MERGE as BEDTOOLS_MERGE_MAX          } from '../../modules/nf-core/bedtools/merge/main'
include { BEDTOOLS_MERGE as BEDTOOLS_MERGE_MIN          } from '../../modules/nf-core/bedtools/merge/main'
include { GNU_SORT                                      } from '../../modules/nf-core/gnu/sort/main'
include { MINIMAP2_INDEX                                } from '../../modules/nf-core/minimap2/index/main'
include { MINIMAP2_ALIGN                                } from '../../modules/nf-core/minimap2/align/main'
include { SAMTOOLS_MERGE                                } from '../../modules/nf-core/samtools/merge/main'
include { SAMTOOLS_SORT                                 } from '../../modules/nf-core/samtools/sort/main'
include { SAMTOOLS_VIEW as SAMTOOLS_VIEW_FILTER_PRIMARY } from '../../modules/nf-core/samtools/view/main'
include { UCSC_BEDGRAPHTOBIGWIG as BED2BW_NORMAL        } from '../../modules/nf-core/ucsc/bedgraphtobigwig/main'
include { UCSC_BEDGRAPHTOBIGWIG as BED2BW_LOG           } from '../../modules/nf-core/ucsc/bedgraphtobigwig/main'
include { UCSC_BEDGRAPHTOBIGWIG as BED2BW_AVGCOV        } from '../../modules/nf-core/ucsc/bedgraphtobigwig/main'
include { GRAPHOVERALLCOVERAGE                          } from '../../modules/local/graphoverallcoverage'
include { GETMINMAXPUNCHES                              } from '../../modules/local/getminmaxpunches'
include { FINDHALFCOVERAGE                              } from '../../modules/local/findhalfcoverage'
include { LONGREADCOVERAGESCALELOG                      } from '../../modules/local/longreadcoveragescalelog'
include { AVGCOV                                        } from '../../modules/local/avgcov'


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
            "bai",
            false,
            false,
    )
    ch_versions         = ch_versions.mix(MINIMAP2_ALIGN.out.versions)

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
        []
    )
    ch_versions         = ch_versions.mix(SAMTOOLS_VIEW_FILTER_PRIMARY.out.versions)

    //
    // MODULE: BAM TO PRIMARY BED
    //
    BEDTOOLS_BAMTOBED(SAMTOOLS_VIEW_FILTER_PRIMARY.out.bam)
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
    ch_coverage_unsorted_bed = BEDTOOLS_GENOMECOV.out.genomecov

    //
    // MODULE: SORT THE PRIMARY BED FILE
    //
    GNU_SORT(
        ch_coverage_unsorted_bed
    )
    ch_versions         = ch_versions.mix( GNU_SORT.out.versions )

    //
    // MODULE: GENERATE MIN AND MAX PUNCHFILES
    //
    GETMINMAXPUNCHES(
        GNU_SORT.out.sorted
    )
    ch_versions         = ch_versions.mix( GETMINMAXPUNCHES.out.versions )

    //
    // MODULE: MERGE MAX DEPTH FILES
    //
    BEDTOOLS_MERGE_MAX(
        GETMINMAXPUNCHES.out.max
    )
    ch_versions         = ch_versions.mix( BEDTOOLS_MERGE_MAX.out.versions )

    //
    // MODULE: MERGE MIN DEPTH FILES
    //
    BEDTOOLS_MERGE_MIN(
        GETMINMAXPUNCHES.out.min
    )
    ch_versions         = ch_versions.mix( BEDTOOLS_MERGE_MIN.out.versions )

    //
    // MODULE: GENERATE DEPTHGRAPH
    //
    GRAPHOVERALLCOVERAGE(
        GNU_SORT.out.sorted
    )
    ch_versions         = ch_versions.mix( GRAPHOVERALLCOVERAGE.out.versions )

    //
    // LOGIC: PREPARING FINDHALFCOVERAGE INPUT
    //
    GNU_SORT.out.sorted
        .combine( GRAPHOVERALLCOVERAGE.out.part )
        .combine( dot_genome )
        .multiMap { meta, file, meta_depthgraph, depthgraph, meta_my_genome, my_genome ->
            halfcov_bed     :       tuple(
                                            [   id : meta.id,
                                                single_end : true
                                            ],
                                            file
                                    )
            genome_file     :       my_genome
            depthgraph_file :       depthgraph
        }
        .set { halfcov_input }

    //
    // MODULE: FIND REGIONS OF HALF COVERAGE
    //
    FINDHALFCOVERAGE(
        halfcov_input.halfcov_bed,
        halfcov_input.genome_file,
        halfcov_input.depthgraph_file
    )
    ch_versions         = ch_versions.mix( FINDHALFCOVERAGE.out.versions )

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
    BED2BW_NORMAL(
        bed2bw_normal_input.ch_coverage_bed,
        bed2bw_normal_input.genome_file
    )
    ch_versions         = ch_versions.mix( BED2BW_NORMAL.out.versions )

    //
    // MODULE: CONVERT COVERAGE TO LOG
    //
    LONGREADCOVERAGESCALELOG(
        GNU_SORT.out.sorted
    )
    ch_versions         = ch_versions.mix(LONGREADCOVERAGESCALELOG.out.versions)

    //
    // LOGIC: PREPARING LOG COVERAGE INPUT
    //
    LONGREADCOVERAGESCALELOG.out.bed
        .combine( dot_genome )
        .combine(reference_tuple)
        .multiMap { meta, file, meta_my_genome, my_genome, ref_meta, ref ->
            ch_coverage_bed :   tuple ([ id: ref_meta.id, single_end: true], file)
            genome_file     :   my_genome
        }
        .set { bed2bw_log_input }

    //
    // MODULE: CALCULATE AVERAGE COVERAGE BASED ON SCAFFOLD
    //
    AVGCOV(
        GNU_SORT.out.sorted,
        bed2bw_log_input.genome_file
    )
    ch_versions             = ch_versions.mix(AVGCOV.out.versions)

    //
    // MODULE: CONVERT BEDGRAPH TO BIGWIG FOR AVERAGE COVERAGE
    //
    BED2BW_AVGCOV(
        AVGCOV.out.avgbed,
        bed2bw_log_input.genome_file
    )
    ch_versions             = ch_versions.mix(BED2BW_AVGCOV.out.versions)

    //
    // MODULE: CONVERT BEDGRAPH TO BIGWIG FOR LOG COVERAGE
    //
    BED2BW_LOG(
        bed2bw_log_input.ch_coverage_bed,
        bed2bw_log_input.genome_file
    )
    ch_versions         = ch_versions.mix(BED2BW_LOG.out.versions)

    emit:
    ch_minbed           = BEDTOOLS_MERGE_MIN.out.bed
    ch_halfbed          = FINDHALFCOVERAGE.out.bed
    ch_maxbed           = BEDTOOLS_MERGE_MAX.out.bed
    ch_bigwig           = BED2BW_NORMAL.out.bigwig
    ch_bigwig_log       = BED2BW_LOG.out.bigwig
    ch_bigwig_avg       = BED2BW_AVGCOV.out.bigwig
    versions            = ch_versions
}
