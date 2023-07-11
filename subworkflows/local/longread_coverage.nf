#!/usr/bin/env nextflow

//
// MODULE IMPORT BLOCK
//
include { BEDTOOLS_BAMTOBED                         } from '../../modules/nf-core/bedtools/bamtobed/main'
include { BEDTOOLS_GENOMECOV                        } from '../../modules/nf-core/bedtools/genomecov/main'
include { BEDTOOLS_MERGE as BEDTOOLS_MERGE_MAX      } from '../../modules/nf-core/bedtools/merge/main'
include { BEDTOOLS_MERGE as BEDTOOLS_MERGE_MIN      } from '../../modules/nf-core/bedtools/merge/main'
include { GNU_SORT                                  } from '../../modules/nf-core/gnu/sort/main'
include { MINIMAP2_INDEX                            } from '../../modules/nf-core/minimap2/index/main'
include { MINIMAP2_ALIGN as MINIMAP2_ALIGN_SPLIT    } from '../../modules/nf-core/minimap2/align/main'
include { MINIMAP2_ALIGN                            } from '../../modules/nf-core/minimap2/align/main'
include { SAMTOOLS_MERGE                            } from '../../modules/nf-core/samtools/merge/main'
include { SAMTOOLS_SORT                             } from '../../modules/nf-core/samtools/sort/main'
include { SAMTOOLS_VIEW                             } from '../../modules/nf-core/samtools/view/main'
include { UCSC_BEDGRAPHTOBIGWIG                     } from '../../modules/nf-core/ucsc/bedgraphtobigwig/main'

include { GRAPHOVERALLCOVERAGE                      } from '../../modules/local/graphoverallcoverage'
include { GETMINMAXPUNCHES                          } from '../../modules/local/getminmaxpunches'
include { FINDHALFCOVERAGE                          } from '../../modules/local/findhalfcoverage'


workflow LONGREAD_COVERAGE {

    take:
    reference_tuple     // Channel: [ val(meta), path(reference_file) ]
    dot_genome          // Channel: [ val(meta), [ path(datafile) ] ]
    reads_path          // Channel: [ val(meta), val( str ) ]

    main:
    ch_versions         = Channel.empty()

    //
    // MODULE: CREATES INDEX OF REFERENCE FILE
    //
    MINIMAP2_INDEX(reference_tuple)
    ch_versions = ch_versions.mix(MINIMAP2_INDEX.out.versions)

    //
    // MODULE: GETS PACBIO READ PATHS FROM READS_PATH
    //
    ch_grabbed_read_paths = GrabFiles(reads_path)

    //
    // LOGIC: PACBIO READS FILES TO CHANNEL
    //
    ch_grabbed_read_paths
           .map { meta, files ->
            tuple(files)
            }
        .flatten()
        .set { ch_read_paths }

    //
    // LOGIC: COMBINE PACBIO READ PATHS WITH MINIMAP2_INDEX OUTPUT
    //
    MINIMAP2_INDEX.out.index
        .combine(ch_read_paths)
        .combine(reference_tuple)
        .map { meta, ref_mmi, read_path, ref_meta, ref_path ->
            tuple([ id: meta.id,
                    single_end: true,
                    split_prefix: read_path.toString().split('/')[-1].split('.fasta.gz')[0]
                ],
                read_path, ref_mmi, true, false, false, file(ref_path).size())
            }
        .branch {
            large: it[6] > 4000000000
            small: it[6] < 4000000000
        }
        .set { mma_input }

    //
    // MODULE: ALIGN READS TO REFERENCE WHEN REFERENCE <5GB PER SCAFFOLD
    //   
    MINIMAP2_ALIGN (
        mma_input.small.map { [it[0], it[1]] },
        mma_input.small.map { it[2] },
        mma_input.small.map { it[3] },
        mma_input.small.map { it[4] },
        mma_input.small.map { it[5] }
    )
    ch_versions = ch_versions.mix(MINIMAP2_ALIGN.out.versions)

    //
    // MODULE: ALIGN READS TO REFERENCE WHEN REFERENCE >5GB PER SCAFFOLD
    //
    MINIMAP2_ALIGN_SPLIT (
        mma_input.large.map { [it[0], it[1]] },
        mma_input.large.map { it[2] },
        mma_input.large.map { it[3] },
        mma_input.large.map { it[4] },
        mma_input.large.map { it[5] }
    )
    ch_versions = ch_versions.mix(MINIMAP2_ALIGN_SPLIT.out.versions)

    //
    // LOGIC: COLLECT OUTPUTTED BAM FILES FROM BOTH PROCESSES
    //        
    MINIMAP2_ALIGN.out.bam
        .mix(MINIMAP2_ALIGN_SPLIT.out.bam)
        .set { ch_bams }

    //
    // LOGIC: PREPARING MERGE INPUT WITH REFERENCE GENOME AND REFERENCE INDEX
    //
    ch_bams
        .map { meta, file ->
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
    // MODULE: MERGES THE BAM FILES IN REGARDS TO THE REFERENCE
    //         EMITS A MERGED BAM
    SAMTOOLS_MERGE(
        collected_files_for_merge,
        reference_tuple, 
        MINIMAP2_INDEX.out.index
    )
    ch_versions = ch_versions.mix(SAMTOOLS_MERGE.out.versions)

    //
    // LOGIC: PREPARING MERGE INPUT WITH REFERENCE GENOME AND REFERENCE INDEX
    //
    SAMTOOLS_MERGE.out.bam
        .combine( reference_tuple )
        .combine( MINIMAP2_INDEX.out.index )
        .map { meta, file, ref_meta, ref, ref_index_meta, ref_index ->
                tuple([ id: meta.id, single_end: true], file, ref, ref_index) }
        .set { view_input }

    //
    // MODULE: EXTRACT READS FOR PRIMARY ASSEMBLY
    //
    SAMTOOLS_VIEW(
        view_input.map { [it[0], it[1], it[3]] },
        view_input.map { [it[0], it[2]] },
        []
    )
    ch_versions = ch_versions.mix(SAMTOOLS_VIEW.out.versions)

    //
    // MODULE: BAM TO PRIMARY BED
    //
    BEDTOOLS_BAMTOBED(SAMTOOLS_VIEW.out.bam)
    ch_versions = ch_versions.mix(BEDTOOLS_BAMTOBED.out.versions)

    //
    // LOGIC: PREPARING Genome2Cov INPUT
    //
    BEDTOOLS_BAMTOBED.out.bed
        .combine(dot_genome)
        .map { meta, file, my_genome_meta, my_genome -> 
            tuple([ id: meta.id, single_end: true], file, 1, my_genome, 'bed')
        }
        .set { genomecov_input }

    //
    // MODULE: GENOME TO COVERAGE BED
    // 
    BEDTOOLS_GENOMECOV(
        genomecov_input.map { [it[0], it[1], it[2]] },
        genomecov_input.map { it[3] },
        genomecov_input.map { it[4] }
    )
    ch_versions = ch_versions.mix(BEDTOOLS_GENOMECOV.out.versions)
    ch_coverage_unsorted_bed = BEDTOOLS_GENOMECOV.out.genomecov

    //
    // MODULE: SORT THE PRIMARY BED FILE
    //
    GNU_SORT(ch_coverage_unsorted_bed)
    ch_versions = ch_versions.mix(GNU_SORT.out.versions)

    //
    // MODULE: GENERATE MIN AND MAX PUNCHFILES
    //
    GETMINMAXPUNCHES(
        GNU_SORT.out.sorted
    )
    ch_versions = ch_versions.mix(GETMINMAXPUNCHES.out.versions)

    //
    // MODULE: MERGE MAX DEPTH FILES
    //
    BEDTOOLS_MERGE_MAX(
        GETMINMAXPUNCHES.out.max
    )
    ch_versions = ch_versions.mix(BEDTOOLS_MERGE_MAX.out.versions)
    ch_maxbed = BEDTOOLS_MERGE_MAX.out.bed

    //
    // MODULE: MERGE MIN DEPTH FILES
    //
    BEDTOOLS_MERGE_MIN(
        GETMINMAXPUNCHES.out.min
    )
    ch_versions = ch_versions.mix(BEDTOOLS_MERGE_MIN.out.versions)

    //
    // MODULE: GENERATE DEPTHGRAPH
    //
    GRAPHOVERALLCOVERAGE(
        GNU_SORT.out.sorted
    )
    ch_versions = ch_versions.mix(GRAPHOVERALLCOVERAGE.out.versions)
    ch_depthgraph = GRAPHOVERALLCOVERAGE.out.part

    //
    // LOGIC: PREPARING FINDHALFCOVERAGE INPUT
    //
    GNU_SORT.out.sorted
        .combine( ch_depthgraph )
        .combine( dot_genome )
        .map { meta, file, meta_depthgraph, depthgraph, meta_my_genome, my_genome -> 
            tuple([ id: meta.id, single_end: true], file, my_genome, depthgraph)
        }
        .set { findhalfcov_input }

    //
    // MODULE: FIND HALF COVERAGE SITES
    //
    FINDHALFCOVERAGE(
        findhalfcov_input.map { [it[0], it[1]] },
        findhalfcov_input.map { it[2] },
        findhalfcov_input.map { it[3] }
    )
    ch_versions = ch_versions.mix(FINDHALFCOVERAGE.out.versions)

    //
    // LOGIC: PREPARING FINDHALFCOVERAGE INPUT
    //
    GNU_SORT.out.sorted
        .combine( dot_genome )
        .map { meta, file, meta_my_genome, my_genome -> 
            tuple([ id: meta.id, single_end: true], file, my_genome)
        }
        .set { bed2bw_input }

    //
    // MODULE: CONVERT BEDGRAPH TO BIGWIG
    //
    UCSC_BEDGRAPHTOBIGWIG(
        bed2bw_input.map { [it[0], it[1]] },
        bed2bw_input.map { it[2] }
    )
    ch_versions = ch_versions.mix(UCSC_BEDGRAPHTOBIGWIG.out.versions)

    emit:
    ch_minbed   = BEDTOOLS_MERGE_MIN.out.bed
    ch_halfbed  = FINDHALFCOVERAGE.out.bed
    ch_maxbed   = BEDTOOLS_MERGE_MAX.out.bed
    ch_bigwig   = UCSC_BEDGRAPHTOBIGWIG.out.bigwig
    versions    = ch_versions 
}

process GrabFiles {
    tag "${meta.id}"
    executor 'local'

    input:
    tuple val(meta), path("in")

    output:
    tuple val(meta), path("in/*.fasta.gz")

    "true"
}