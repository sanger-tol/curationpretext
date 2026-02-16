process EXTRACT_TELOMERE {
    tag "${meta.id}"
    label 'process_single'

    conda "conda-forge::coreutils=9.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ubuntu:20.04' :
        'docker.io/ubuntu:20.04' }"

    input:
    tuple val( meta ), path( file )

    output:
    tuple val( meta ), file( "*bed" )   , emit: bed
    tuple val( meta ), file("*bedgraph"), emit: bedgraph
    tuple val("${task.process}"), val('awk'), eval("awk -Wversion | sed '1!d; s/.*Awk //; s/,.*//'"), topic: versions, emit: versions_extracttelomere

    script:
    def prefix  = task.ext.prefix ?: "${meta.id}"
    """
    awk 'BEGIN {OFS = "\\t"} {print \$2, \$4, \$5}' ${file} | sed 's/>//g' > ${prefix}_telomere.bed
    awk 'BEGIN {OFS = "\\t"} {print \$2,\$4,\$5,(((\$5-\$4)<0)?-(\$5-\$4):(\$5-\$4))}' ${file} | sed 's/>//g' > ${prefix}_telomere.bedgraph
    """

    stub:
    def prefix  = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_telomere.bed
    touch ${prefix}_telomere.bedgraph
    """
}
