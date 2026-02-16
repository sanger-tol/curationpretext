process FIND_TELOMERE_WINDOWS {
    tag "${meta.id}"
    label 'process_low'

    conda "bioconda::java-jdk=8.0.112"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/java-jdk:8.0.112--1' :
        'biocontainers/java-jdk:8.0.112--1' }"

    input:
    tuple val(meta), path(file)

    output:
    tuple val( meta ), file( "*.windows" ) , emit: windows
    tuple val("${task.process}"), val('find_telomere_windows'), eval("echo '1.0.0'"), topic: versions, emit: versions_telomerewindows

    when:
    task.ext.when == null || task.ext.when

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def telomere_jar = task.ext.telomere_jar ?: ''
    def telomere_jvm_params = task.ext.telomere_jvm_params ?: ''
    def telomere_window_cut = task.ext.telomere_window_cut ?: 99.9
    """
    java ${telomere_jvm_params} -cp ${projectDir}/bin/${telomere_jar} FindTelomereWindows $file $telomere_window_cut > ${prefix}.windows
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.windows
    """

}
