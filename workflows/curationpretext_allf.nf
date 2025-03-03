/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowCurationpretext.initialise(params, log)

// Check input path parameters to see if they exist
def checkPathParamList = [ params.longread, params.cram, params.input ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { GENERATE_MAPS                             } from '../subworkflows/local/generate_maps'
include { ACCESSORY_FILES                           } from '../subworkflows/local/accessory_files'
include { PRETEXT_INGESTION as PRETEXT_INGEST_SNDRD } from '../subworkflows/local/pretext_ingestion'
include { PRETEXT_INGESTION as PRETEXT_INGEST_HIRES } from '../subworkflows/local/pretext_ingestion'


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//

include { CUSTOM_DUMPSOFTWAREVERSIONS   } from '../modules/nf-core/custom/dumpsoftwareversions/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow CURATIONPRETEXT_ALLF {

    main:
    ch_versions = Channel.empty()

    input_fasta     = Channel.fromPath(params.input, checkIfExists: true, type: 'file')
    cram_dir        = Channel.fromPath(params.cram, checkIfExists: true, type: 'dir')
    longread        = Channel.fromPath(params.longread, checkIfExists: true, type: 'dir')

    ch_reference = input_fasta.map { fasta ->
        tuple(
            [
                id: params.sample,
                aligner: params.aligner,
                ref_size: fasta.size(),
            ],
            fasta
        )
    }
    ch_cram_reads = cram_dir.map { dir ->
        tuple(
            [
                id: params.sample,
            ],
            dir
        )
    }
    ch_longread_reads = longread.map { dir ->
        tuple(
            [
                id: params.sample,
                single_end: true,
                read_type: params.longread_type,
            ],
            dir
        )
    }

    //
    // SUBWORKFLOW: GENERATE SUPPLEMENTARY FILES FOR PRETEXT INGESTION
    //
    ACCESSORY_FILES (
        ch_reference,
        ch_longread_reads
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
        ACCESSORY_FILES.out.coverage_avg_bw,
        ACCESSORY_FILES.out.coverage_log_bw,
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
        ACCESSORY_FILES.out.coverage_avg_bw,
        ACCESSORY_FILES.out.coverage_log_bw,
        ACCESSORY_FILES.out.telo_file,
        ACCESSORY_FILES.out.repeat_file
    )
    ch_versions         = ch_versions.mix( PRETEXT_INGEST_SNDRD.out.versions )

    //
    // SUBWORKFLOW: Collates version data from prior subworflows
    //
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    emit:
    software_ch = CUSTOM_DUMPSOFTWAREVERSIONS.out.yml
    versions_ch = CUSTOM_DUMPSOFTWAREVERSIONS.out.versions

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
    }
    // TreeValProject.summary(workflow, reference_tuple, summary_params, projectDir)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
