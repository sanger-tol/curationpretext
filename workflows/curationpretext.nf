/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// NF-CORE SUBWORKFLOWS
include { FASTA_CLEAN_FAIDX                                 } from '../subworkflows/nf-core/fasta_clean_faidx/main'

// LOCAL MODULES
include { PRETEXT_GRAPH as PRETEXT_INGEST_SNDRD             } from '../modules/local/pretext/graph/main'
include { PRETEXT_GRAPH as PRETEXT_INGEST_HIRES             } from '../modules/local/pretext/graph/main'
include { PRETEXT_GRAPH as PRETEXT_INGEST_ULTRA             } from '../modules/local/pretext/graph/main'

// LOCAL SUBWORKFLOWS
include { ACCESSORY_FILES                                   } from '../subworkflows/local/accessory_files/main'

// SANGER-TOL SUBWORKFLOWS
include { CRAM_MAP_ILLUMINA_HIC as ALIGN_CRAM               } from '../subworkflows/sanger-tol/cram_map_illumina_hic/main'
include { PAIRS_CREATE_CONTACT_MAPS as CREATE_MAPS_STDRD    } from '../subworkflows/sanger-tol/pairs_create_contact_maps/main'
include { PAIRS_CREATE_CONTACT_MAPS as CREATE_MAPS_HIRES    } from '../subworkflows/sanger-tol/pairs_create_contact_maps/main'
include { PAIRS_CREATE_CONTACT_MAPS as CREATE_MAPS_ULTRA    } from '../subworkflows/sanger-tol/pairs_create_contact_maps/main'

// SANGER-TOL MODULES
include { PRETEXTANNOTATE                                   } from '../modules/sanger-tol/pretextannotate/main'

// FUNCTION IMPORTS
include { paramsSummaryMap                                  } from 'plugin/nf-schema'
include { paramsSummaryMultiqc                              } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML                            } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText                            } from '../subworkflows/local/utils_nfcore_curationpretext_pipeline'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow CURATIONPRETEXT {
    take:
    ch_reference
    ch_reads
    ch_cram_reads
    ch_mapped_bam
    ch_snapshot_order
    val_snapshot_generation
    val_snapshot_annotate
    val_juicer_generation
    val_teloseq
    val_selected_aligner
    val_run_gap
    val_run_telomere
    val_run_repeats
    val_run_coverage
    val_run_busco
    val_run_pebble
    val_run_hires
    val_run_ultra
    val_no_tracks
    val_split_telomere
    val_cram_chunk_size
    val_replace_dots
    val_track_indexes
    outdir

    main:

    //
    // SUBWORKFLOW: UNZIP FASTA, UPPERCASE SEQUENCE,
    //              CLEAN HEADER (optional) AND GENERATE INDEX
    //
    FASTA_CLEAN_FAIDX (
        ch_reference,
        val_replace_dots,
        true,               // We always want the .sizes file
        false               // We don't need the .dict file
    )


    //
    // LOGIC: IN SOME CASES THE USER MAY NOT NEED ALL OR A SELECT GROUP OF
    //          ACCESSORY FILES SO WE HAVE AN OPTION TO TURN THEM OFF
    //
    full_list = [
        "gap track": val_run_gap,
        "telomere track": val_run_telomere,
        "repeats track": val_run_repeats,
        "coverage track": val_run_coverage,
        "busco track": val_run_busco,
        "pebble track": val_run_pebble
    ]


    log.info "ACCESSORY TRACK OPTIONS: $full_list"

    ch_empty_file       = channel.fromPath("${baseDir}/assets/EMPTY.txt")

    if (val_no_tracks) {
        gaps_file       = ch_empty_file
        cove_file       = ch_empty_file
        telo_file       = ch_empty_file
        rept_file       = ch_empty_file
        busc_file       = ch_empty_file
        pebb_file       = ch_empty_file

    } else {
        //
        // SUBWORKFLOW: GENERATE SUPPLEMENTARY FILES FOR PRETEXT INGESTION
        //
        ACCESSORY_FILES (
            FASTA_CLEAN_FAIDX.out.reference.map{ meta, file -> tuple([id: meta.id], file) },
            ch_reads,
            val_teloseq,
            val_split_telomere,
            val_run_telomere,
            val_run_repeats,
            val_run_coverage,
            val_run_busco,
            val_run_pebble,
            val_run_gap,
            val_track_indexes,
            val_no_tracks,
            FASTA_CLEAN_FAIDX.out.sizes
        )

        gaps_file       = ACCESSORY_FILES.out.gap_file
        cove_file       = ACCESSORY_FILES.out.coverage_output
        telo_file       = ACCESSORY_FILES.out.telo_file
        rept_file       = ACCESSORY_FILES.out.repeat_file
    }


    //
    // SUBWORKFLOW: MAP CRAM IF READS NOT ALREADY MAPPED
    //
    ALIGN_CRAM (
        FASTA_CLEAN_FAIDX.out.reference,
        ch_cram_reads,
        val_selected_aligner,
        val_cram_chunk_size
    )

    mapped_bam          = ch_mapped_bam.mix( ALIGN_CRAM.out.bam )


    //
    // LOGIC: IF params.snapshot_order IS PROVIDED, USE IT TO ORDER SNAPSHOTS
    //        OTHERWISE, THE MODULE SHOULD STILL RUN WITHOUT ORDERING AND
    //        PRODUCE AN EMPTY CHANNEL. ONLY NEEDED FOR STDRD
    //
    ch_snapshot_custom_order = FASTA_CLEAN_FAIDX.out.reference
        .combine(ch_snapshot_order)
        .map { meta, _fasta, order_file -> [meta, order_file] }


    //
    // SUBWORKFLOW: MAP THE PRETEXT FILE AND TAKE SNAPSHOT
    //              STNDRD IS THE ONLY VARIANT WE ARE ANNOTATING WITH OTHER PARAMS
    //              DUE TO HOW RESOURCE INTENSIVE THEY SNAPSHOT IS WITH HIGHER RESOLUTION
    //              AND WE ONLY NEED 1 JUICER MAP
    //
    CREATE_MAPS_STDRD (
        mapped_bam,
        [[:],[]],
        ch_snapshot_custom_order,
        true,                       // Pretext generation, always true
        val_snapshot_generation,
        false,                      // cooler map generation, which we won't be using
        val_juicer_generation,      // Juicer generation, optional need for genomenotes
        []                          // Cooler cload parameters
    )


    //
    // MODULE: ANNOTATE THE PRETEXT SNAPSHOT FILE WITH SCAFFOLD NAMES AND SIZES
    //
    filtered_sizes = FASTA_CLEAN_FAIDX.out.sizes.filter { _meta, _file -> val_snapshot_annotate }

    filtered_sizes.map { _meta, _file ->
        log.warn "Annotation currently relies on the original FASTA sizes file generated as part of this pipeline!"
        log.warn "This means that if you've supplied a custom order for the snapshot, the annotation will be wrong!"
    }

    PRETEXTANNOTATE(
        filtered_sizes,
        CREATE_MAPS_STDRD.out.pretext_png
    )


    //
    // SUBWORKFLOW: MAP THE PRETEXT FILE
    //
    CREATE_MAPS_HIRES (
        mapped_bam.filter{ val_run_hires },
        [[:],[]],
        channel.of([[:],[]]),
        true,
        false,
        false,
        false,
        []
    )

    //
    // SUBWORKFLOW: MAP THE PRETEXT FILE
    //              IF val_run_ultra IS "true" CALCULATE WHETHER THE REF IS > 4GB AND MAP ULTRA
    //              IF val_run_ultra IS "force" MAP ULTRA
    //
    def ultra_input     = mapped_bam
        .combine(FASTA_CLEAN_FAIDX.out.reference)
        .filter { _mapped_meta, _bam, _ref_meta, ref_fasta ->
            val_run_ultra == "force" || (val_run_ultra == "yes" && ref_fasta.size() > 4.GB)
        }
        .map { mapped_meta, bam, _ref_meta, _ref_fasta ->
            [mapped_meta, bam]
        }

    CREATE_MAPS_ULTRA (
        ultra_input,
        [[:],[]],
        channel.of([[:],[]]),
        true,
        false,
        false,
        false,
        []
    )


    //
    // MODULE: INGEST ACCESSORY FILES INTO PRETEXT BY DEFAULT
    //          - ADAPTED FROM TREEVAL
    //
    PRETEXT_INGEST_SNDRD (
        CREATE_MAPS_STDRD.out.pretext.filter { val_no_tracks },
        gaps_file,
        cove_file,
        telo_file,
        rept_file,
        val_split_telomere
    )


    //
    // MODULE: INGEST ACCESSORY FILES INTO PRETEXT BY DEFAULT
    //          - ADAPTED FROM TREEVAL
    //
    PRETEXT_INGEST_HIRES (
        CREATE_MAPS_HIRES.out.pretext.filter { val_no_tracks },
        gaps_file,
        cove_file,
        telo_file,
        rept_file,
        val_split_telomere
    )


    //
    // MODULE: INGEST ACCESSORY FILES INTO PRETEXT BY DEFAULT
    //          - ADAPTED FROM TREEVAL
    //
    PRETEXT_INGEST_ULTRA (
        CREATE_MAPS_ULTRA.out.pretext.filter { val_no_tracks },
        gaps_file,
        cove_file,
        telo_file,
        rept_file,
        val_split_telomere
    )

    def ch_versions     = channel.empty()

    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name:  'curationpretext_software_'  + 'versions.yml',
            sort: true,
            newLine: true
        )
    emit:
    versions            = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
