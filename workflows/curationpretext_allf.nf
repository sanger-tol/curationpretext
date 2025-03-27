/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { GENERATE_MAPS                             } from '../subworkflows/local/generate_maps'
include { ACCESSORY_FILES                           } from '../subworkflows/local/accessory_files'
include { PRETEXT_GRAPH as PRETEXT_INGEST_SNDRD     } from '../modules/local/pretext_graph'
include { PRETEXT_GRAPH as PRETEXT_INGEST_HIRES     } from '../modules/local/pretext_graph'

include { paramsSummaryMap                          } from 'plugin/nf-schema'
include { paramsSummaryMultiqc                      } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML                    } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText                    } from '../subworkflows/local/utils_nfcore_curationpretext_pipeline'
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow CURATIONPRETEXT_ALLF {
    take:
    ch_reference
    ch_reads
    ch_cram_reads
    val_teloseq

    main:
    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: GENERATE SUPPLEMENTARY FILES FOR PRETEXT INGESTION
    //
    ACCESSORY_FILES (
        ch_reference,
        ch_reads,
        val_teloseq
    )
    ch_versions         = ch_versions.mix( ACCESSORY_FILES.out.versions )


    //
    // SUBWORKFLOW: GENERATE ONLY PRETEXT MAPS, NO EXTRA FILES
    //
    GENERATE_MAPS (
        ch_reference,
        ch_cram_reads
    )
    ch_versions         = ch_versions.mix( GENERATE_MAPS.out.versions )


    //
    // MODULE: INGEST ACCESSORY FILES INTO PRETEXT BY DEFAULT
    //          - ADAPTED FROM TREEVAL
    //
    PRETEXT_INGEST_SNDRD (
        GENERATE_MAPS.out.standrd_pretext,
        ACCESSORY_FILES.out.gap_file,
        ACCESSORY_FILES.out.coverage_bw,
        ACCESSORY_FILES.out.telo_file,
        ACCESSORY_FILES.out.repeat_file
    )
    ch_versions         = ch_versions.mix( PRETEXT_INGEST_SNDRD.out.versions )


    //
    // MODULE: INGEST ACCESSORY FILES INTO PRETEXT BY DEFAULT
    //          - ADAPTED FROM TREEVAL
    //
    PRETEXT_INGEST_HIRES (
        GENERATE_MAPS.out.highres_pretext,
        ACCESSORY_FILES.out.gap_file,
        ACCESSORY_FILES.out.coverage_bw,
        ACCESSORY_FILES.out.telo_file,
        ACCESSORY_FILES.out.repeat_file
    )
    ch_versions         = ch_versions.mix( PRETEXT_INGEST_SNDRD.out.versions )


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
