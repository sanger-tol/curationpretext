process GET_MIN_MAX_PUNCHES{
    tag "${meta.id}"
    label "process_single"

    conda "conda-forge::coreutils=9.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'docker.io/ubuntu:20.04' }"

    input:
    tuple val(meta), path(bedfile)

    output:
    tuple val(meta), path ( '*zero.bed' )   , optional: true    , emit: min
    tuple val(meta), path ( '*max.bed' )    , optional: true    , emit: max
    path "versions.yml"                     , emit: versions

    script:
    // Module is being kept in current state rather than moved into a GAWK module
    // due to multiple outputs

    def MINXMAX_VERSION = "2.0"
    def VERSION = "9.1" // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    """
    awk '{ if (\$4 == 0) {print \$0 >> "zero.bed" } else if (\$4 > 1000) {print \$0 >> "max.bed"}}' ${bedfile}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        GET_MIN_MAX_PUNCHES: $MINXMAX_VERSION
        coreutils: $VERSION
    END_VERSIONS
    """

    stub:
    def MINXMAX_VERSION = "2.0"
    def VERSION = "9.1"  // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    """
    touch max.bed
    touch min.bed

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        getminmaxpunches: $MINXMAX_VERSION
        coreutils: $VERSION
    END_VERSIONS
    """
}
