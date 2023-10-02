# sanger-tol/curationpretext: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.0 - UNSC Infinity - [2023-10-02]

Initial release of sanger-tol/curationpretext, created with the [sager-tol](https://nf-co.re/) template.

### `Added`
- Subworkflow to generate tracks containing telomeric sites.
- Subworkflow to generate Pretext maps and images
- Subworkflow to generate repeat density tracks.
- Subworkflow to generate longread coverage tracks from pacbio data.
- Subworkflow to generate gap tracks.

### Parameters

### Software Dependencies

Note, since the pipeline is using Nextflow DSL2, each process will be run with its own Biocontainer. This means that on occasion it is entirely possible for the pipeline to be using different versions of the same tool. However, the overall software dependency changes compared to the last release have been listed below for reference.

| Module                                 | Old Version | New Versions     |
| -------------------------------------- | ----------- | ---------------- |
| bamtobed_sort ( bedtools + samtools )  | -           | 2.31.0 + 1.17    |
| bedtools                               | -           | 2.31.0           |
| cram_filter_align_bwamem2_fixmate_sort | -           |                  |
| ^ ( samtools + bwamem2 ) ^             | -           | 1.16.1 + 2.2.1   |
| extract_cov_id ( coreutils )           | -           | 9.1              |
| extract_repeat ( perl )                | -           | 5.26.2           |
| extract_telo ( coreutils )             | -           | 9.1              |
| find_telomere_regions ( gcc )          | -           | 7.1.0            |
| find_telomere_windows ( java-jdk )     | -           | 8.0.112          |
| gap_length ( coreutils )               | -           | 9.1              |
| generate_cram_csv ( samtools )         | -           | 1.17             |
| get_largest_scaff ( coreutils )        | -           | 9.1              |
| gnu-sort                               | -           | 8.25             |
| pretextmap + samtools                  | -           | 0.1.9 + 1.17     |
| seqtk                                  | -           | 1.4              |
| tabix                                  | -           | 1.11             |
| ucsc                                   | -           | 377              |
| windowmasker (blast)                   | -           | 2.14.0           |

### Fixed

### Dependencies

### Deprecated
