process GAP_LENGTH {
    tag "$meta.id"
    label 'process_tiny'

    conda "conda-forge::coreutils=9.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'docker.io/ubuntu:20.04' }"

    input:
    tuple val( meta ), path( input )

    output:
    tuple val( meta ), file( "*bedgraph" )  , emit: bed
    path "versions.yml"                     , emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def GAP_VERSION = "2.0"
    def VERSION = "9.1" // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    """
    cat "${input}" \\
    | awk '{print \$0"\\t"sqrt((\$3-\$2)*(\$3-\$2))}' > ${prefix}_gap.bedgraph

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gap_length: $GAP_VERSION
        coreutils: $VERSION
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def GAP_VERSION = "2.0"
    def VERSION = "9.1"
    """
    touch ${prefix}_gap.bedgraph

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gap_length: $GAP_VERSION
        coreutils: $VERSION
    END_VERSIONS
    """
}
