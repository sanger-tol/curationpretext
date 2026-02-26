def fn_get_validated_channel (data_type, tolid_meta, files_list) {
    // Based on the the functions added in TreeVal - commit: 61f4ad9
    // Edited to be a function working on the raw yaml data
    // rather than channels as it was previously

    // Initialise defaults
    def fofn_files = []
    def direct_files = []

    // Process each file - separate FOFN from direct files
    files_list.each { file_path ->
        if (file_path.toString().contains(".fofn")) {
            def fofn_content = file(file_path).text.split('\n')
                .collect { data -> data.trim() }
                .findAll { file -> file } // Remove empty lines
            fofn_files.addAll(fofn_content)
        } else {
            direct_files.add(file_path)
        }
    }

    // Combine all files
    def all_files = direct_files + fofn_files

    // Validate files based on data type
    if (data_type == "cram") {
        def invalid_files = all_files.findAll { cram ->
            !cram.toString().contains(".cram") &&
            !cram.toString().contains(".bam")
        }
        if (invalid_files.size() > 0) {
            error "[Error] One of the input hic files does not match cram format. Invalid files: ${invalid_files}"
        }
    } else if (data_type == "longread") {
        def invalid_files = all_files.findAll { reads ->
            !reads.toString().contains(".fasta.gz") &&
            !reads.toString().contains(".fa.gz") &&
            !reads.toString().contains(".fn.gz")
        }
        if (invalid_files.size() > 0) {
            error "[Error] One of the input longread files does not match expected formats (fn.gz, fa.gz, fasta.gz). Invalid files: ${invalid_files}"
        }
    }

    // get lengths of the total list of files and unique(list of files)
    // a difference in these numbers mean there is a duplicate
    def raw_list = all_files.size()
    def unique_list = all_files.toSet().size()

    // This may not bring the error to the surface, check the .nextflow.log for details
    if (raw_list != unique_list) {
        error "[Treeval: Error] There is a duplicate value in your ${data_type} list, check your inputs! Found ${raw_list} total items but only ${unique_list} unique items."
    }

    // Create the resolved channel tuple
    def resolved_channel = channel.of(
        [
            tolid_meta,
            all_files.collect { new_file -> file(new_file, checkIfExists: true) }
        ]
    )

    return resolved_channel
}
