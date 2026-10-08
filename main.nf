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
    mapping_statistics
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
        mapping_statistics,
        outdir
    )

    emit:
    telomere_files          = CURATIONPRETEXT.out.telomere_file
    gap_files               = CURATIONPRETEXT.out.gap_file
    coverage_files          = CURATIONPRETEXT.out.coverage_file
    repeat_files            = CURATIONPRETEXT.out.repeat_file
    pretext_snapshot        = CURATIONPRETEXT.out.pretext_png
    pretext_annotated_png   = CURATIONPRETEXT.out.pretext_annotated_png
    pretext_annotated_gif   = CURATIONPRETEXT.out.pretext_annotated_gif
    pretext_annotated_tif   = CURATIONPRETEXT.out.pretext_annotated_tif
    pretext_standard        = CURATIONPRETEXT.out.pretext_standard
    pretext_hires           = CURATIONPRETEXT.out.pretext_hires
    pretext_ultra           = CURATIONPRETEXT.out.pretext_ultra
    hic_file                = CURATIONPRETEXT.out.hic_file
    pretext_standard_tracks = CURATIONPRETEXT.out.pretext_standard_tracked
    pretext_hires_tracks    = CURATIONPRETEXT.out.pretext_hires_tracked
    pretext_ultra_tracks    = CURATIONPRETEXT.out.pretext_ultra_tracked
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow {

    main:
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
        params.snapshot_generation,
        params.snapshot_annotation,
        params.juicer_generation,
        PIPELINE_INITIALISATION.out.teloseq,
        params.input,
        params.aligner,
        params.run_gap,
        params.run_telomere,
        params.run_repeats,
        params.run_coverage,
        params.run_busco,
        params.run_pebble,
        params.run_hires,
        params.run_ultra,
        params.split_telomere,
        params.cram_chunk_size,
        params.replace_dots,
        params.generate_track_indexes,
        params.no_tracks,
        params.mapping_statistics,
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

    publish:
    telomere_files          = SANGER_TOL_CURATIONPRETEXT.out.telomere_files
    gap_files               = SANGER_TOL_CURATIONPRETEXT.out.gap_files
    coverage_files          = SANGER_TOL_CURATIONPRETEXT.out.coverage_files
    repeat_files            = SANGER_TOL_CURATIONPRETEXT.out.repeat_files
    pretext_snapshot        = SANGER_TOL_CURATIONPRETEXT.out.pretext_snapshot
    pretext_annotated_png   = SANGER_TOL_CURATIONPRETEXT.out.pretext_annotated_png
    pretext_annotated_gif   = SANGER_TOL_CURATIONPRETEXT.out.pretext_annotated_gif
    pretext_annotated_tif   = SANGER_TOL_CURATIONPRETEXT.out.pretext_annotated_tif
    pretext_standard        = SANGER_TOL_CURATIONPRETEXT.out.pretext_standard
    pretext_hires           = SANGER_TOL_CURATIONPRETEXT.out.pretext_hires
    pretext_ultra           = SANGER_TOL_CURATIONPRETEXT.out.pretext_ultra
    hic_file                = SANGER_TOL_CURATIONPRETEXT.out.hic_file
    pretext_standard_tracks = SANGER_TOL_CURATIONPRETEXT.out.pretext_standard_tracks
    pretext_hires_tracks    = SANGER_TOL_CURATIONPRETEXT.out.pretext_hires_tracks
    pretext_ultra_tracks    = SANGER_TOL_CURATIONPRETEXT.out.pretext_ultra_tracks
}

output {
    telomere_files {
        path { files ->
            "accessory_files/"
        }
    }
    gap_files {
        path { files ->
            "accessory_files/"
        }
    }
    coverage_files {
        path { files ->
            "accessory_files/"
        }
    }
    repeat_files {
        path { files ->
            "accessory_files/"
        }
    }
    pretext_snapshot {
        path { meta, path ->
            "pretext_snapshot/"
        }
    }
    pretext_annotated_png {
        path { meta, path ->
            "pretext_snapshot/"
        }
    }
    pretext_annotated_gif {
        path { meta, path ->
            "pretext_snapshot/"
        }
    }
    pretext_annotated_tif {
        path { meta, path ->
            "pretext_snapshot/"
        }
    }
    pretext_standard {
        path { meta, path ->
            "pretext_maps_raw/"
        }
    }
    pretext_hires {
        path { meta, path ->
            "pretext_maps_raw/"
        }
    }
    pretext_ultra {
        path { meta, path ->
            "pretext_maps_raw/"
        }
    }
    hic_file {
        path { meta, path ->
            "hic_files/"
        }
    }
    pretext_standard_tracks {
        path { meta, path ->
            "pretext_maps_processed/"
        }
    }
    pretext_hires_tracks {
        path { meta, path ->
            "pretext_maps_processed/"
        }
    }
    pretext_ultra_tracks {
        path { meta, path ->
            "pretext_maps_processed/"
        }
    }

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
