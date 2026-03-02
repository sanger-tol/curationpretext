process TELOMERE_WINDOWS {
    tag "${meta.id}"
    label 'process_low'

    conda "bioconda::java-jdk=8.0.112"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/java-jdk:8.0.112--1' :
        'biocontainers/java-jdk:8.0.112--1' }"

    input:
    tuple val(meta), path(telomere)

    output:
    tuple val(meta), path("*.windows") , emit: windows
    tuple val("${task.process}"), val('find_telomere_windows'), val("1.0.0"), topic: versions, emit: versions_telomerewindows

    when:
    task.ext.when == null || task.ext.when

    script:
    // WARNING: This module includes the telomere.jar binary and its wrapper telomere_windows.sh
    // as module binaries in ${moduleDir}/resources/usr/bin/. To use this module, you will
    // either have to copy these two files to ${projectDir}/bin or set the option
    // nextflow.enable.moduleBinaries = true in your nextflow.config file.

    def prefix      = task.ext.prefix ?: "${meta.id}"
    def args        = task.ext.args   ?: ""

    // Dynamically generate java mem needs based on task.memory
    // Taken from: nf-core/umicollapse
    def max_heap_size_mega = (task.memory.toMega() * 0.9).intValue()
    def max_stack_size_mega = 999 //most java jdks will not allow Xss > 1GB, so fixing this to the allowed max

    """
    telomere_windows.sh \\
        -Xmx${max_heap_size_mega}M \\
        -Xss${max_stack_size_mega}M \\
        FindTelomereWindows $telomere \\
        $args \\
        > ${prefix}.windows
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.windows
    """

}
