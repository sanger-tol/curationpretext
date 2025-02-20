process PRETEXT_GRAPH {
    tag "$meta.id"
    label 'process_single'

    container "quay.io/sanger-tol/pretext:0.0.2-yy5-c4"

    // Exit if running this module with -profile conda / -profile mamba
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        error "PRETEXT_GRAPH module does not support Conda. Please use Docker / Singularity instead."
    }

    input:
    tuple val(meta),    path(pretext_file,      stageAs: 'pretext.pretext.input')
    tuple val(gap),     path(gap_file,          stageAs: 'gap.bed')
    tuple val(cov),     path(coverage,          stageAs: 'coverage.bigWig')
    tuple val(log),     path(log_coverage,      stageAs: 'log_cov.bigWig')
    tuple val(avg),     path(avg_coverage)
    tuple val(telo),    path(telomere_file,     stageAs: 'telo.bedgraph')
    tuple val(rep),     path(repeat_density,    stageAs: 'repeats.bigWig')

    output:
    tuple val(meta), path("*.pretext")  , emit: pretext
    path "versions.yml"                 , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args         = task.ext.args ?: ''
    def prefix       = task.ext.prefix ?: "${meta.id}"
    def PRXT_VERSION = '0.0.6'
    def UCSC_VERSION = '447' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.

    """
    bigWigToBedGraph ${coverage} /dev/stdout | PretextGraph ${args} -i ${pretext_file} -n "coverage" -o coverage.pretext.part

    bigWigToBedGraph  ${repeat_density} /dev/stdout | PretextGraph ${args} -i coverage.pretext.part -n "repeat_density" -o repeat.pretext.part

    bigWigToBedGraph  ${avg_coverage} /dev/stdout | PretextGraph ${args} -i repeat.pretext.part -n "avg_coverage" -o avg.pretext.part

    if [[ ${gap.sz} -ge 1 && ${telo.sz} -ge 1 ]]
    then
        echo "GAP AND TELO have contents!"
        cat ${gap_file} | PretextGraph ${args} -i avg.pretext.part -n "${gap.ft}" -o gap.pretext.part
        cat ${telomere_file} | awk -v OFS='\t' '{\$4 *= 1000; print}' | PretextGraph -i gap.pretext.part -n "${telo.ft}" -o ${prefix}.pretext

    elif [[ ${gap.sz} -ge 1 && ${telo.sz} -eq 0 ]]
    then
        echo "GAP file has contents!"
        cat ${gap_file} | PretextGraph ${args} -i avg.pretext.part -n "${gap.ft}" -o ${prefix}.pretext

    elif [[ ${gap.sz} -eq 0 && ${telo.sz} -ge 1 ]]
    then
        echo "TELO file has contents!"
        cat ${telomere_file} | awk -v OFS='\t' '{\$4 *= 1000; print}' | PretextGraph ${args} -i avg.pretext.part -n "${telo.ft}" -o ${prefix}.pretext

    else
        echo "NO GAP OR TELO FILE WITH CONTENTS - renaming part file"
        mv avg.pretext.part ${prefix}.pretext
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        PretextGraph: ${PRXT_VERSION}
        bigWigToBedGraph: ${UCSC_VERSION}
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    def PRXT_VERSION = '0.0.6'
    def UCSC_VERSION = '448' // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.
    """
    touch ${prefix}.pretext

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        PretextGraph: ${PRXT_VERSION}
        bigWigToBedGraph: ${UCSC_VERSION}
    END_VERSIONS
    """
}
