include { FIND_TELOMERE_WINDOWS         } from '../../../modules/local/find/telomere_windows/main'
include { EXTRACT_TELOMERE              } from '../../../modules/local/extract/telomere/main'

workflow TELO_EXTRACTION {
    take:
    telomere_file //tuple(meta, file)

    main:

    //
    // MODULE: GENERATES A WINDOWS FILE FROM THE ABOVE
    //
    FIND_TELOMERE_WINDOWS (
        telomere_file
    )


    def windows_file    = FIND_TELOMERE_WINDOWS.out.windows
    def safe_windows    = windows_file.ifEmpty { channel.empty() }


    //
    // MODULE: Extract the telomere data from the FIND_TELOMERE
    //          file and reformat into bed
    //
    EXTRACT_TELOMERE(
        safe_windows
    )


    emit:
    bedgraph_file   = EXTRACT_TELOMERE.out.bedgraph
}
