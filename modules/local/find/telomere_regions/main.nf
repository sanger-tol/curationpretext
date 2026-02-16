process FIND_TELOMERE_REGIONS {
    tag "${meta.id}"
    label 'process_low'

    container 'quay.io/sanger-tol/telomere:0.0.1-c1'

    input:
    tuple val(meta), path(file)
    val (telomereseq)

    output:
    tuple val( meta ), file( "*.telomere" ) , emit: telomere
    tuple val("${task.process}"), val('find_telomere_regions'), eval("echo '1.0.0'"), topic: versions, emit: versions_telomerewindows

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "FIND_TELOMERE_REGIONS module does not support Conda. Please use Docker / Singularity instead."
    }

    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    find_telomere ${file} $telomereseq > ${prefix}.telomere
    """

    stub:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "FIND_TELOMERE_REGIONS module does not support Conda. Please use Docker / Singularity instead."
    }

    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.telomere
    """

}
