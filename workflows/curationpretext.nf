/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { GENERATE_MAPS                             } from '../subworkflows/local/generate_maps/main'
include { ACCESSORY_FILES                           } from '../subworkflows/local/accessory_files/main'
include { PRETEXT_GRAPH as PRETEXT_INGEST_SNDRD     } from '../modules/local/pretext/graph/main'
include { PRETEXT_GRAPH as PRETEXT_INGEST_HIRES     } from '../modules/local/pretext/graph/main'

include { paramsSummaryMap                          } from 'plugin/nf-schema'
include { paramsSummaryMultiqc                      } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML                    } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText                    } from '../subworkflows/local/utils_nfcore_curationpretext_pipeline'
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
    ch_versions         = Channel.empty()
    ch_empty_file       = Channel.fromPath("${baseDir}/assets/EMPTY.txt")

    //
    // LOGIC: IN SOME CASES THE USER MAY NOT NEED ALL OR A SELECT GROUP OF
    //          ACCESSORY FILES SO WE HAVE AN OPTION TO TURN THEM OFF
    //
    dont_generate_tracks  = params.skip_tracks ? params.skip_tracks.split(",") : "NONE"

    full_list = [
        "gap",
        "telo",
        "repeat",
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
            ch_reference,
            ch_reads,
            val_teloseq
        )
        ch_versions         = ch_versions.mix( ACCESSORY_FILES.out.versions )

        gaps_file           = ACCESSORY_FILES.out.gap_file
        cove_file           = ACCESSORY_FILES.out.longread_output
        telo_file           = ACCESSORY_FILES.out.telo_file
        rept_file           = ACCESSORY_FILES.out.repeat_file
    }



    //
    // SUBWORKFLOW: GENERATE ONLY PRETEXT MAPS, NO EXTRA FILES
    //              - GENERATE_MAPS IS THE MINIMAL OUTPUT EXPECTED FROM THIS PIPELLINE
    //
    GENERATE_MAPS (
        ch_reference,
        ch_cram_reads
    )
    ch_versions         = ch_versions.mix( GENERATE_MAPS.out.versions )


    if (!dont_generate_tracks.contains("ALL")) {

        //
        // MODULE: INGEST ACCESSORY FILES INTO PRETEXT BY DEFAULT
        //          - ADAPTED FROM TREEVAL
        //
        PRETEXT_INGEST_SNDRD (
            GENERATE_MAPS.out.standrd_pretext,
            gaps_file,
            cove_file,
            telo_file,
            rept_file,
        )
        ch_versions         = ch_versions.mix( PRETEXT_INGEST_SNDRD.out.versions )


        //
        // MODULE: INGEST ACCESSORY FILES INTO PRETEXT BY DEFAULT
        //          - ADAPTED FROM TREEVAL
        //
        PRETEXT_INGEST_HIRES (
            GENERATE_MAPS.out.highres_pretext,
            gaps_file,
            cove_file,
            telo_file,
            rept_file,
        )
        ch_versions         = ch_versions.mix( PRETEXT_INGEST_SNDRD.out.versions )
    }


    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'sanger-tol_'  +  'curationpretext_software_' + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")


}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
