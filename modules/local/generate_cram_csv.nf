process GENERATE_CRAM_CSV {
    tag "${meta.id}"
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-1a6fe65bd6674daba65066aa796ed8f5e8b4687b:688e175eb0db54de17822ba7810cc9e20fa06dd5-0' :
        'biocontainers/mulled-v2-1a6fe65bd6674daba65066aa796ed8f5e8b4687b:688e175eb0db54de17822ba7810cc9e20fa06dd5-0' }"

    input:
    tuple val(meta), path(crampath)

    output:
    tuple val(meta), path('*.csv'), emit: csv
    path "versions.yml",            emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "GENERATE_CRAM_CSV module does not support Conda. Please use Docker / Singularity instead."
    }

    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    generate_cram_csv.sh $crampath ${prefix}_cram.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//' )
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//' )
    END_VERSIONS
    """
}
