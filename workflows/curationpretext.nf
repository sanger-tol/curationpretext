/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// NF-CORE SUBWORKFLOWS
include { FASTA_CLEAN_FAIDX                                 } from '../subworkflows/nf-core/fasta_clean_faidx/main'

//LOCAL MODULES
include { PRETEXT_GRAPH as PRETEXT_INGEST_SNDRD             } from '../modules/local/pretext/graph/main'
include { PRETEXT_GRAPH as PRETEXT_INGEST_HIRES             } from '../modules/local/pretext/graph/main'
include { PRETEXT_GRAPH as PRETEXT_INGEST_ULTRA             } from '../modules/local/pretext/graph/main'

// LOCAL SUBWORKFLOWS
// include { ACCESSORY_FILES                                   } from '../subworkflows/local/accessory_files/main'

// SANGER-TOL SUBWORKFLOWS
include { PRETEXT_ACCESSORY_FILES as ACCESSORY_FILES        } from '../subworkflows/sanger-tol/pretext_accessory_files/main'
include { CRAM_MAP_ILLUMINA_HIC as ALIGN_CRAM               } from '../subworkflows/sanger-tol/cram_map_illumina_hic/main'
include { PAIRS_CREATE_CONTACT_MAPS as CREATE_MAPS_STDRD    } from '../subworkflows/sanger-tol/pairs_create_contact_maps/main'
include { PAIRS_CREATE_CONTACT_MAPS as CREATE_MAPS_HIRES    } from '../subworkflows/sanger-tol/pairs_create_contact_maps/main'
include { PAIRS_CREATE_CONTACT_MAPS as CREATE_MAPS_ULTRA    } from '../subworkflows/sanger-tol/pairs_create_contact_maps/main'

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
    ch_teloseq
    val_aligner
    val_run_hires
    val_run_ultra
    val_split_telomere
    val_cram_chunk_size
    val_coverage_track
    val_gap_track
    val_telo_track
    val_repeat_track
    val_pebble_track
    val_busco_track
    val_track_indexes
    val_no_tracks
    outdir

    main:

    //
    // MODULE: UNZIP INPUTS IF NEEDED, UPPERCASE THE SEQUENCE, TRIM HEADERS AND INDEX
    //
    FASTA_CLEAN_FAIDX (
        ch_reference,
        true,
        false
    )


    //
    // LOGIC: IN SOME CASES THE USER MAY NOT NEED ALL OR A SELECT GROUP OF
    //          ACCESSORY FILES SO WE HAVE AN OPTION TO TURN THEM OFF
    //

    ch_empty_file         = channel.fromPath("${baseDir}/assets/EMPTY.txt")

    full_list = [
        "gap track": val_gap_track,
        "telomere track": val_telo_track,
        "repeat track": val_repeat_track,
        "coverage track": val_coverage_track,
        "busco track (placeholder)": val_busco_track,
        "pebble track (placeholder)": val_pebble_track,
    ]

    log.info "TRACK OPTIONS: $full_list"

    if (val_no_tracks) {
        log.info "SKIPPING ALL TRACK GENERATION"

        gaps_file           = !val_gap_track        ?: ch_empty_file
        cove_file           = !val_coverage_track   ?: ch_empty_file
        telo_file           = !val_telo_track       ?: ch_empty_file
        rept_file           = !val_repeat_track     ?: ch_empty_file

    } else {
        //
        // SUBWORKFLOW: GENERATE SUPPLEMENTARY FILES FOR PRETEXT INGESTION
        //
        ACCESSORY_FILES (
            FASTA_CLEAN_FAIDX.out.reference.map{ meta, file -> tuple([id: meta.id], file) },
            FASTA_CLEAN_FAIDX.out.sizes,
            ch_reads,
            ch_teloseq,
            val_split_telomere,
            val_telo_track,
            val_gap_track,
            val_coverage_track,
            val_repeat_track,
            val_busco_track,
            val_pebble_track,
            val_track_indexes
        )

        gaps_file           = ACCESSORY_FILES.out.gap_file.map{ _meta, file -> file }.ifEmpty{ [] }
        cove_file           = ACCESSORY_FILES.out.coverage_file.map{ _meta, file -> file }.ifEmpty{ [] }
        telo_file           = ACCESSORY_FILES.out.telo_file.map{ _meta, files -> files }.collect().ifEmpty{ [] }
        rept_file           = ACCESSORY_FILES.out.repeat_file.map{ _meta, file -> file }.ifEmpty{ [] }
    }


    //
    // SUBWORKFLOW: MAP CRAM IF READS NOT ALREADY MAPPED
    //
    ALIGN_CRAM (
        FASTA_CLEAN_FAIDX.out.reference,
        ch_cram_reads,
        val_aligner,
        val_cram_chunk_size
    )

    mapped_bam = ch_mapped_bam.mix( ALIGN_CRAM.out.bam )


    //
    // SUBWORKFLOW: MAP THE PRETEXT FILE AND TAKE SNAPSHOT
    //
    CREATE_MAPS_STDRD (
        mapped_bam,
        [[:],[]],
        ch_snapshot_order,
        true,
        params.snapshot_generation,
        false,
        false,
        []
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
    //              IF val_run_ultra IS "yes" CALCULATE WHETHER THE REF IS > 4GB AND MAP ULTRA
    //              IF val_run_ultra IS "force" MAP ULTRA
    //
    def ultra_input = mapped_bam
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
        CREATE_MAPS_STDRD.out.pretext.filter { !val_no_tracks },
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
        CREATE_MAPS_HIRES.out.pretext.filter { !val_no_tracks },
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
        CREATE_MAPS_ULTRA.out.pretext.filter { !val_no_tracks },
        gaps_file,
        cove_file,
        telo_file,
        rept_file,
        val_split_telomere
    )

    def ch_versions = channel.empty()

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
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
