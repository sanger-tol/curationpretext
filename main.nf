#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    sanger-tol/curationpretext
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/sanger-tol/curationpretext
    Website: https://pipelines.tol.sanger.ac.uk/curationpretext
----------------------------------------------------------------------------------------
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT FUNCTIONS / MODULES / SUBWORKFLOWS / WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { CURATIONPRETEXT           } from './workflows/curationpretext'
include { PIPELINE_INITIALISATION   } from './subworkflows/local/utils_nfcore_curationpretext_pipeline'
include { PIPELINE_COMPLETION       } from './subworkflows/local/utils_nfcore_curationpretext_pipeline'

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
    mapped
    teloseq
    input_file_string
    aligner
    skip_tracks
    run_hires
    split_telomere
    cram_chunk_size

    main:

    CURATIONPRETEXT (
        input_fasta,
        reads,
        cram,
        mapped,
        teloseq,
        input_file_string,
        aligner,
        skip_tracks,
        run_hires,
        split_telomere,
        cram_chunk_size
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
        [],                      // We are not using the samplesheet for this pipeline
        params.help,
        params.help_full,
        params.show_hidden
    )

    // MOVE THE CHANNEL CREATION INTO THE PIPELINE INITIALISATION

    //
    // WORFKLOW: Run main sanger-tol/curationpretext analysis pipeline
    //
    SANGER_TOL_CURATIONPRETEXT (
        PIPELINE_INITIALISATION.out.ch_reference,
        PIPELINE_INITIALISATION.out.ch_longreads,
        PIPELINE_INITIALISATION.out.ch_cram_reads,
        PIPELINE_INITIALISATION.out.ch_mapped_bam,
        PIPELINE_INITIALISATION.out.teloseq,
        params.input,
        params.aligner,
        params.skip_tracks,
        params.run_hires,
        params.split_telomere,
        params.cram_chunk_size
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
        params.hook_url
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
