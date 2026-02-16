/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// NF-CORE MODULES
include { GAWK as GAWK_UPPER_SEQUENCE                       } from '../modules/nf-core/gawk/main'
include { SAMTOOLS_FAIDX                                    } from '../modules/nf-core/samtools/faidx/main'
include { GUNZIP                                            } from '../modules/nf-core/gunzip/main'

//LOCAL MODULES
include { PRETEXT_GRAPH as PRETEXT_INGEST_SNDRD             } from '../modules/local/pretext/graph/main'
include { PRETEXT_GRAPH as PRETEXT_INGEST_HIRES             } from '../modules/local/pretext/graph/main'

// LOCAL SUBWORKFLOWS
include { ACCESSORY_FILES                                   } from '../subworkflows/local/accessory_files/main'

// SANGER-TOL SUBWORKFLOWS
include { CRAM_MAP_ILLUMINA_HIC as ALIGN_CRAM               } from '../subworkflows/sanger-tol/cram_map_illumina_hic/main'
include { PAIRS_CREATE_CONTACT_MAPS as CREATE_MAPS_STDRD    } from '../subworkflows/sanger-tol/pairs_create_contact_maps/main'
include { PAIRS_CREATE_CONTACT_MAPS as CREATE_MAPS_HIRES    } from '../subworkflows/sanger-tol/pairs_create_contact_maps/main'


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
    val_teloseq

    main:
    ch_empty_file       = Channel.fromPath("${baseDir}/assets/EMPTY.txt")


    ch_reference
        .branch { meta, file ->
            zipped: file.name.endsWith('.gz')
            unzipped: !file.name.endsWith('.gz')
        }
        .set {ch_input}

    //
    // MODULE: UNZIP INPUTS IF NEEDED
    //
    GUNZIP (
        ch_input.zipped
    )


    //
    // LOGIC: MIX CHANELS WHICH MAY OR MAY NOT BE EMPTY INTO A SINGLE QUEUE CHANNEL
    //
    unzipped_input = Channel.empty()

    unzipped_input
        .mix(ch_input.unzipped, GUNZIP.out.gunzip)
        .set { unzipped_reference }


    //
    // MODULE: UPPERCASE THE REFERENCE SEQUENCE
    //
    GAWK_UPPER_SEQUENCE(
        unzipped_reference,
        [],
        false,
    )
    ch_upper_ref    = GAWK_UPPER_SEQUENCE.out.output


    //
    // MODULE: GENERATE INDEX OF REFERENCE FASTA
    //
    SAMTOOLS_FAIDX (
        ch_upper_ref.map { meta, file -> [meta, file, []] },
        false
    )


    //
    // LOGIC: IN SOME CASES THE USER MAY NOT NEED ALL OR A SELECT GROUP OF
    //          ACCESSORY FILES SO WE HAVE AN OPTION TO TURN THEM OFF
    //

    dont_generate_tracks  = params.skip_tracks ? params.skip_tracks.split(",") : "NONE"

    full_list = [
        "gap",
        "telo",
        "repeats",
        "coverage",
        "NONE",
        "ALL"
    ]

    if (!full_list.containsAll(dont_generate_tracks) && !full_list.containsAll(dont_generate_tracks)) {
        exit 1, "There is an extra argument given on Command Line: \n Check contents of: $dont_generate_tracks\nMaster list is: $full_list"
    }

    log.info "SKIPPING TRACK GENERATION FOR: $dont_generate_tracks"

    if (dont_generate_tracks.contains("ALL")) {
        gaps_file           = ch_empty_file
        cove_file           = ch_empty_file
        telo_file           = ch_empty_file
        rept_file           = ch_empty_file

    } else {
        //
        // SUBWORKFLOW: GENERATE SUPPLEMENTARY FILES FOR PRETEXT INGESTION
        //
        ACCESSORY_FILES (
            ch_upper_ref,
            ch_reads,
            val_teloseq,
            SAMTOOLS_FAIDX.out.fai
        )

        gaps_file           = ACCESSORY_FILES.out.gap_file
        cove_file           = ACCESSORY_FILES.out.longread_output
        telo_file           = ACCESSORY_FILES.out.telo_file
        rept_file           = ACCESSORY_FILES.out.repeat_file
    }


    //
    // SUBWORKFLOW: MAP CRAM IF READS NOT ALREADY MAPPED
    //
    def selected_aligner = (params.aligner == "AUTO") ?
        (fasta_size > 5e9 ? "minimap2" : "bwamem2") :
        params.aligner

    ALIGN_CRAM (
        ch_upper_ref.filter{ _meta, _file -> !params.pre_mapped },
        ch_cram_reads,
        selected_aligner,
        params.cram_chunk_size
    )


    //
    // SUBWORKFLOW: MAP THE PRETEXT FILE AND TAKE SNAPSHOT
    //
    CREATE_MAPS_STDRD (
        ALIGN_CRAM.out.bam,
        [[:],[]],
        true,
        true,
        false,
        false,
        []
    )


    //
    // SUBWORKFLOW: MAP THE PRETEXT FILE
    //
    CREATE_MAPS_HIRES (
        ALIGN_CRAM.out.bam.filter{ _meta, _file -> params.run_hires },
        [[:],[]],
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
        CREATE_MAPS_STDRD.out.pretext.filter { !dont_generate_tracks.contains("ALL") },
        gaps_file,
        cove_file,
        telo_file,
        rept_file,
        params.split_telomere
    )


    //
    // MODULE: INGEST ACCESSORY FILES INTO PRETEXT BY DEFAULT
    //          - ADAPTED FROM TREEVAL
    //
    PRETEXT_INGEST_HIRES (
        CREATE_MAPS_HIRES.out.pretext.filter { params.run_hires && !dont_generate_tracks.contains("ALL") },
        gaps_file,
        cove_file,
        telo_file,
        rept_file,
        params.split_telomere
    )


    //
    // Collate and save software versions
    //
    def topic_versions = Channel.topic("versions")
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

    softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'sanger-tol_'  +  'curationpretext_software_' + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")


    emit:
    versions       = ch_collated_versions   // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
