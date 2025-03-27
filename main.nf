#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    sanger-tol/curationpretext
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/sanger-tol/curationpretext
    Website: https://nf-co.re/curationpretext
    Slack  : https://nfcore.slack.com/channels/curationpretext
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { CURATIONPRETEXT_ALLF      } from './workflows/curationpretext_allf'
//include { CURATIONPRETEXT_MAPS      } from './workflows/curationpretext_maps'
include { PIPELINE_INITIALISATION   } from './subworkflows/local/utils_nfcore_curationpretext_pipeline'
include { PIPELINE_COMPLETION       } from './subworkflows/local/utils_nfcore_curationpretext_pipeline'
include { getGenomeAttribute        } from './subworkflows/local/utils_nfcore_curationpretext_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOWS FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/


//
// WORKFLOW: Run main sanger-tol/curationpretext analysis pipeline
//
workflow SANGER_TOL_CURATIONPRETEXT {
    take:
    input_fasta
    reads
    cram
    sample
    teloseq
    aligner
    read_type
    map_order

    main:

    CURATIONPRETEXT_ALLF (
        input_fasta,
        reads,
        cram,
        sample,
        teloseq,
        aligner,
        read_type,
        map_order
    )
    // CURATIONPRETEXT_MAPS
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    //
    // SUBWORKFLOW: Run initialisation tasks
    //
    PIPELINE_INITIALISATION (
        params.version,
        params.validate_params,
        params.monochrome_logs,
        args,
        params.outdir,
        []                      // We are not using the samplesheet for this pipeline
    )

    // MOVE THE CHANNEL CREATION INTO THE PIPELINE INITIALISATION

    //
    // WORFKLOW: Run main sanger-tol/curationpretext analysis pipeline
    //
    SANGER_TOL_CURATIONPRETEXT (
        params.input,
        params.reads,
        params.cram,
        params.sample,
        params.teloseq,
        params.aligner,
        params.read_type,
        params.map_order
    )

    //
    // SUBWORKFLOW: Run completion tasks
    //
    PIPELINE_COMPLETION (
        params.email,
        params.email_on_fail,
        params.plaintext_email,
        params.outdir,
        params.monochrome_logs,
        params.hook_url,
        []                      // We are not using MultiQC for this pipeline
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
