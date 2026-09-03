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
    snapshot_order
    snapshot_generation
    snapshot_annotate
    juicer_generation
    teloseq
    input_file_string
    aligner
    run_gap
    run_telomere
    run_repeats
    run_coverage
    run_busco
    run_pebble
    run_hires
    run_ultra
    split_telomere
    cram_chunk_size
    replace_dots
    track_indexes
    no_tracks
    outdir

    main:

    //
    // LOGIC: IDEALLY THIS SHOULD BE DONE IN THE PIPELINE_INITIALISATION
    //        SUBWORKFLOW, HOWEVER, THE VALUE WOULD BE CONVERTED TO A CHANNEL
    //        WHICH THEN CANNOT BE USED TO GENERATE A STRING FOR THE SW
    //
    def fasta_size = file(input_file_string).size()
    def selected_aligner = (aligner == "AUTO") ?
        (fasta_size > 5e9 ? "minimap2" : "bwamem2") :
        aligner


    //
    // WORKFLOW: ACTUAL CURATIONPRETEXT WORKFLOW
    //
    CURATIONPRETEXT (
        input_fasta,
        reads,
        cram,
        mapped,
        snapshot_order,
        snapshot_generation,
        snapshot_annotate,
        juicer_generation,
        teloseq,
        selected_aligner,
        run_gap,
        run_telomere,
        run_repeats,
        run_coverage,
        run_busco,
        run_pebble,
        run_hires,
        run_ultra,
        no_tracks,
        split_telomere,
        cram_chunk_size,
        replace_dots,
        track_indexes,
        outdir
    )
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
        [], // We are not using the samplesheet for this pipeline
        params.help,
        params.help_full,
        params.show_hidden
    )


    //
    // WORFKLOW: Run main sanger-tol/curationpretext analysis pipeline
    //
    SANGER_TOL_CURATIONPRETEXT (
        PIPELINE_INITIALISATION.out.ch_reference,
        PIPELINE_INITIALISATION.out.ch_longreads,
        PIPELINE_INITIALISATION.out.ch_cram_reads,
        PIPELINE_INITIALISATION.out.ch_mapped_bam,
        PIPELINE_INITIALISATION.out.ch_snapshot_order,
        params.snapshot_generation.toBoolean(),
        params.snapshot_annotation.toBoolean(),
        params.juicer_generation.toBoolean(),
        PIPELINE_INITIALISATION.out.teloseq,
        params.input,
        params.aligner,
        params.run_gap.toBoolean(),
        params.run_telomere.toBoolean(),
        params.run_repeats.toBoolean(),
        params.run_coverage.toBoolean(),
        params.run_busco.toBoolean(),
        params.run_pebble.toBoolean(),
        params.run_hires.toBoolean(),
        params.run_ultra,
        params.split_telomere.toBoolean(),
        params.cram_chunk_size,
        params.replace_dots.toBoolean(),
        params.generate_track_indexes.toBoolean(),
        params.no_tracks.toBoolean(),
        params.outdir,
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
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
