process TELOMERE_FINDTELOMERE {
    tag "${meta.id}"
    label 'process_low'

    container 'quay.io/sanger-tol/telomere:0.0.2-c1'

    input:
    tuple val(meta), path(reference), val(telomereseq)
    val split_windows

    output:
    tuple val(meta), path("*.telomere"), emit: telomere
    tuple val(meta), path("*.fwd.telomere.bed"), emit: telomere_bed_fwd, optional: true
    tuple val(meta), path("*.rev.telomere.bed"), emit: telomere_bed_rev, optional: true
    // Use an exact basename: `*.all.windows` also matches `*.fwd.windows` / `*.rev.windows`, which breaks split-mode staging.
    tuple val(meta), path("*.all.windows"), emit: windows_all, optional: true
    tuple val(meta), path("*.fwd.windows"), emit: windows_fwd, optional: true
    tuple val(meta), path("*.rev.windows"), emit: windows_rev, optional: true
    tuple val("${task.process}"), val('java'), eval("java -version 2>&1 | head -n 1 | cut -d '\"' -f2"), topic: versions, emit: versions_java
    // find_telomere has no --version; pin to container tag (bump when `container` changes)
    tuple val("${task.process}"), val('find_telomere'), val('0.0.2'), topic: versions, emit: versions_find_telomere

    when:
    task.ext.when == null || task.ext.when

    script:
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "FINDTELOMERE module does not support Conda. Please use Docker / Singularity instead."
    }

    def args = task.ext.args ?: ''
    def args2 = task.ext.args2 ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def split_opt = split_windows ? '--split' : ''
    def split_windows_output = split_windows ? '' : "> ${prefix}.all.windows"
    def max_heap_size_mega = (task.memory.toMega() * 0.9).intValue()
    def max_stack_size_mega = 999 //most java jdks will not allow Xss > 1GB, so fixing this to the allowed max

    """
    find_telomere ${args} ${reference} ${telomereseq} | awk '{print \$1"\\t"\$(NF-4)"\\t"\$(NF-3)"\\t"\$(NF-2)"\\t"\$(NF-1)"\\t"\$NF}' - > ${prefix}.telomere

    java \\
        -Xmx${max_heap_size_mega}M \\
        -Xss${max_stack_size_mega}M  \\
        -cp /opt/telomere/telomere.jar \\
        FindTelomereWindows \\
        ${split_opt} ${prefix}.telomere \\
        ${args2} \\
        ${split_windows_output}
    """

    stub:
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "FINDTELOMERE module does not support Conda. Please use Docker / Singularity instead."
    }
    def prefix = task.ext.prefix ?: "${meta.id}"
    def split_opt = split_windows ? '--split ' : ''
    """
    printf "stub\\n" > ${prefix}.telomere
    printf "stub\\n" > ${prefix}.fwd.telomere.bed
    printf "stub\\n" > ${prefix}.rev.telomere.bed
    if [ -n "${split_opt}" ]; then
        printf "stub\\n" > ${prefix}.fwd.windows
        printf "stub\\n" > ${prefix}.rev.windows
    else
        printf "stub\\n" > ${prefix}.all.windows
    fi
    """

}
