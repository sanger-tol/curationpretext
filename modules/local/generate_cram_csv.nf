process GENERATE_CRAM_CSV {
    tag "${meta.id}"
    label 'process_single'

    container 'quay.io/sanger-tol/cramfilter_bwamem2_minimap2_samtools_perl:0.001-c1'

    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "GENERATE_CRAM_CSV module does not support Conda. Please use Docker / Singularity instead."
    }

    input:
    tuple val(meta), path(crampath)

    output:
    tuple val(meta), path('*.csv'), emit: csv
    path "versions.yml",            emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
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
