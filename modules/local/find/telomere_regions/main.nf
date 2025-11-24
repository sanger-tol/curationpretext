nextflow.preview.types = true

process FIND_TELOMERE_REGIONS {
    tag "${meta.id}"
    label 'process_low'

    container 'quay.io/sanger-tol/telomere:0.0.1-c1'

    input:
    (meta, file) : Tuple<Map, Path>
    telomereseq  : String

    output:
    telomere = tuple(meta, file("*.telomere"))
    versions = file("versions.yml")

    when:
    task.ext.when == null || task.ext.when

    script:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("FIND_TELOMERE_REGIONS module does not support Conda. Please use Docker / Singularity instead.")
    }

    def prefix = task.ext.prefix ?: "${meta.id}"
    def VERSION = "1.0"
    // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    """
    find_telomere ${file} ${telomereseq} > ${prefix}.telomere

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        find_telomere: ${VERSION}
    END_VERSIONS
    """

    stub:
    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error("FIND_TELOMERE_REGIONS module does not support Conda. Please use Docker / Singularity instead.")
    }

    def prefix = task.ext.prefix ?: "${meta.id}"
    def VERSION = "1.0"
    // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    """
    touch ${prefix}.telomere

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        find_telomere: ${VERSION}
    END_VERSIONS
    """
}
