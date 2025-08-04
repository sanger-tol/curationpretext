include { FIND_TELOMERE_WINDOWS         } from '../../../modules/local/find/telomere_windows/main'
include { EXTRACT_TELOMERE              } from '../../../modules/local/extract/telomere/main'

workflow TELO_EXTRACTION {
    take:
    telomere_file //tuple(meta, file)

    main:
    ch_versions         = Channel.empty()

    //
    // MODULE: GENERATES A WINDOWS FILE FROM THE ABOVE
    //
    FIND_TELOMERE_WINDOWS (
        telomere_file
    )
    ch_versions         = ch_versions.mix( FIND_TELOMERE_WINDOWS.out.versions )


    def windows_file    = FIND_TELOMERE_WINDOWS.out.windows
    def safe_windows    = windows_file.ifEmpty { Channel.empty() }

    //
    // MODULE: Extract the telomere data from the FIND_TELOMERE
    //          file and reformat into bed
    //
    EXTRACT_TELOMERE(
        safe_windows
    )
    ch_versions         = ch_versions.mix( EXTRACT_TELOMERE.out.versions )


    emit:
    bedgraph_file   = EXTRACT_TELOMERE.out.bedgraph
    versions        = ch_versions

}
