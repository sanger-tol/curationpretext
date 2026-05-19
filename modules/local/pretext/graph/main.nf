process PRETEXT_GRAPH {
    tag "$meta.id"
    label 'process_single'

    container "quay.io/sanger-tol/pretext:0.0.9-yy5-c2"

    input:
    tuple val(meta),        path(pretext_file)
    path(gap_file,          stageAs: 'gap_file.bed')
    path(coverage,          stageAs: 'coverage.bw')
    path(telomere_file,     stageAs: 'telomere/*')
    path(repeat_density,    stageAs: 'repeat_density.bw')
    val(split_telo_bool)

    output:
    tuple val(meta), path("*.pretext")  , emit: pretext
    tuple val("${task.process}"), val('ucsc'), eval("echo $VERSION"), topic: versions, emit: versions_ucsc
    tuple val("${task.process}"), val('PretextGraph'), eval('PretextGraph | sed "/Version/!d; s/.*Version //"'), emit: versions_pretextgraph, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "PRETEXT GRAPH module does not _currently_ support Conda. Please use Docker / Singularity instead."
    }

    def args         = task.ext.args ?: ''
    def prefix       = task.ext.prefix ?: "${meta.id}"
    VERSION = '447' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.

    // Using single [ ] as nextflow will use sh where possible not bash
    //
    // Core Args must match the below (taken from PretextView), this allows
    // the use of keyboard shortcuts for main tracks:
    //
    // data_type_dic{  // use this data_type
    //     {"default", 0, },
    //     {"repeat_density", 1},
    //     {"gap", 2},
    //     {"coverage", 3},
    //     {"coverage_avg", 4},
    //     {"telomere", 5},
    //     {"not_weighted", 6}
    // };
    //
    """
    echo "PROCESSING ESSENTIAL FILES"

    if [ -s "${coverage}" ]; then
        echo "PROCESSING COVERAGE..."
        bigWigToBedGraph ${coverage} /dev/stdout | PretextGraph ${args} -i ${pretext_file} -n "coverage" -o coverage.pretext.part
    else
        echo "SKIPPING COVERAGE"
        mv ${pretext_file} coverage.pretext.part
    fi

    if [ -s "${repeat_density}" ]; then
        echo "PROCESSING REPEAT_DENSITY..."
        bigWigToBedGraph  ${repeat_density} /dev/stdout | PretextGraph ${args} -i coverage.pretext.part -n "repeat_density" -o repeat.pretext.part
    else
        echo "SKIPPING REPEAT_DENSITY"
        mv coverage.pretext.part repeat.pretext.part
    fi

    echo "NOW PROCESSING NON-ESSENTIAL files"
    input_file="repeat.pretext.part"
    if [ -s "${gap_file}" ]; then
        echo "Processing GAP file..."
        cat "${gap_file}" | PretextGraph ${args} -i repeat.pretext.part -n "gap" -o gap.pretext.part
        input_file="gap.pretext.part"
    fi

    # Check if telomere directory has any files
    if [ "\$(ls -A telomere 2>/dev/null)" ]; then
        file_telox=""
        file_fwd=""
        file_rev=""
        file_all=""

        for file in telomere/*.bedgraph; do
            [ -e "\$file" ] || continue  # skip if no match
            fname=\$(basename "\$file")

            case "\$fname" in
                *.telox.*)
                    file_telox="\$file"
                    ;;
                *.fwd.*)
                    file_fwd="\$file"
                    ;;
                *.rev.*)
                    file_rev="\$file"
                    ;;
                *.all.*)
                    file_all="\$file"
                    ;;
                *)
                    continue
                    ;;
            esac
        done

        if [ -s "\$file_all" ]; then
            echo "Processing OG_TELOMERE file: \$file_all"

            # Must be named "telomere"
            PretextGraph $args -i "\$input_file" -n "telomere" -o telo_0.pretext < "\$file_all"
        else
            echo "OG TELOMERE file - Could be empty or missing"
            cp "\$input_file" telo_0.pretext
        fi

        if [ -s "\$file_telox" ]; then
            echo "Processing TELOX_TELOMERE file: \$file_telox"
            PretextGraph $args -i telo_0.pretext -n "telox_telomere" -o telo_1.pretext < "\$file_telox"
        else
            echo "TELOX file - Could be empty or missing"
            cp telo_0.pretext telo_1.pretext
        fi

        if [ -s "\$file_fwd" ]; then
            echo "Processing 5-Prime TELOMERE file: \$file_fwd"
            PretextGraph $args -i telo_1.pretext -n "FWD_telomere" -o telo_2.pretext < "\$file_fwd"
        else
            echo "5-Prime TELOMERE file - Could be empty or missing"
            cp telo_1.pretext telo_2.pretext
        fi

        if [ -s "\$file_rev" ]; then
            echo "Processing 3-Prime TELOMERE file: \$file_rev"
            PretextGraph $args -i telo_2.pretext -n "REV_telomere" -o "${prefix}.pretext" < "\$file_rev"
        else
            echo "3-Prime TELOMERE file - Could be empty or missing"
            cp telo_2.pretext "${prefix}.pretext"
        fi

    else
        cp "\$input_file" "${prefix}.pretext"
    fi
    """

    stub:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "PRETEXT GRAPH module does not _currently_ support Conda. Please use Docker / Singularity instead."
    }

    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.pretext
    """
}
