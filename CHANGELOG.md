# sanger-tol/curationpretext: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [[1.3.0](https://github.com/sanger-tol/curationpretext/releases/tag/1.3.0)] - UNSC Pillar-of-Autumn - [2025-02-27]

### Added and Fixed

- Update to Template version 3.2.
  - PIPELINE_INITIALISATION now initialises the channels for the pipeline.
- `all_output` flag which, by default, will only output the post-processed pretext files.
- Deleted the PRETEXT\*INGESTION\* subworkflow, replaced with a direct call to the PRETEXT_GRAPH module.
- Updated PRETEXT_GRAPH for better logic and to match the same update to TreeVal.
  - Inputs to pretext graph are now optional/conditional depedning on runs from previous steps.
- Updated NF_TEST config to ignore modules and subworkflows.
- Updated modules.config to reflect all the above changes.
- Updated nextflow.config to cleanup by default -- previously this was added as a profile.
- We no longer use the avg or log coverage tracks, processes related to these have been removed.
- Shell blocks have been replaced with script blocks.
- Removed the MAPS_ONLY entry point, entry points are being depreciated and the subworkflow not used. This can be re-added on request.
- Replaced a 5 modules with GAWK to remove bad practise (`cat > sed` commands).

### Paramters

| Old Version | New Versions |
| ----------- | ------------ |
| NA          | --all_output |

### Software Dependencies

Note, since the pipeline is using Nextflow DSL2, each process will be run with its own Biocontainer. This means that on occasion it is entirely possible for the pipeline to be using different versions of the same tool. However, the overall software dependency changes compared to the last release have been listed below for reference.

| Module                             | Old Version | New Versions |
| ---------------------------------- | ----------- | ------------ |
| `gawk`                             | -           | 5.3.0        |
| `rename_ids` ( coreutils )         | 9.1         | REMOVED      |
| `replace_dots` ( coreutils )       | 9.1         | REMOVED      |
| `gap_length` ( coreutils )         | 9.1         | REMOVED      |
| `reformat_intersect` ( coreutils ) | 9.1         | REMOVED      |
| `generate_genome_file` (coreutils) | 9.1 | REMOVED |
| `custom_dumpsoftwareversions`      | -           | Python 3.11.7 + yaml 5.4.1 |


## [[1.2.0](https://github.com/sanger-tol/curationpretext/releases/tag/1.2.0)] - UNSC Spirit-of-Fire - [2025-02-28]

### Added

- Updated pretext graph (bug fix version).
- Updated pretext module as the tool now offers version output.
- Enums have been added to the schema to protect against invalid values for some fields.
- Docker run options have been updated to run as User - @mahesh-panchal
- Pipeline code has been trimmed and made more concise - @mahesh-panchal
- Pipeline file and folder searching has been made more robust - @mahesh-panchal
- Renamed the longread parameters to read parameters.
- By request, cleanup is enabled by default.

### Software Dependencies

Note, since the pipeline is using Nextflow DSL2, each process will be run with its own Biocontainer. This means that on occasion it is entirely possible for the pipeline to be using different versions of the same tool. However, the overall software dependency changes compared to the last release have been listed below for reference.

| Module       | Old Version | New Versions |
| ------------ | ----------- | ------------ |
| `pretextgraph` | 0.0.6       | 0.0.8-c1     |

### Paramters

| Old Version     | New Versions |
| --------------- | ------------ |
| --longread_type | --read_type  |
| --longread      | --reads      |

## [[1.1.1](https://github.com/sanger-tol/curationpretext/releases/tag/1.1.1)] - UNSC Delphi (H1) - [2025-02-18]

### Added

- Added NF-Test
- Updated pretext graph (bug fix version)

### Software Dependencies

Note, since the pipeline is using Nextflow DSL2, each process will be run with its own Biocontainer. This means that on occasion it is entirely possible for the pipeline to be using different versions of the same tool. However, the overall software dependency changes compared to the last release have been listed below for reference.

| Module       | Old Version | New Versions |
| ------------ | ----------- | ------------ |
| `pretextgraph` | 0.0.6       | 0.0.6        |

## [[1.1.0](https://github.com/sanger-tol/curationpretext/releases/tag/1.1.0)] - UNSC Delphi - [2024-12-09]

### Added

- Added map_order so that the output maps are defaulted to unsorted and can be selected as sorted.
- Updating all modules.
- Removing Anaconda 'defaults' channel.
- Updating local module containers.
- Update to LICENSE and CITATIONS files.
- Update algorithms at play for memory allocation, particulary minimap2.
- Parity update to TreeVal as the mapping subworkflow is based on the treeval implementation.
- Fixed some version output being generated incorrectly.

### Paramters

| Old Version | New Versions |
| ----------- | ------------ |
| -           | --map_order  |

### Software Dependencies

Note, since the pipeline is using Nextflow DSL2, each process will be run with its own Biocontainer. This means that on occasion it is entirely possible for the pipeline to be using different versions of the same tool. However, the overall software dependency changes compared to the last release have been listed below for reference.

| Module                                       | Old Version   | New Versions               |
| -------------------------------------------- | ------------- | -------------------------- |
| `get_avcov`                                    | -             | 1.0.0                      |
| `bamtobed_sort` ( bedtools + samtools )        | 2.31.0 + 1.17 | 2.31.1 + 1.17              |
| `bedtools` ( all modules)                      | 2.31.1        | -                          |
| `bwamem2_index`                                | -             | 2.2.1                      |
| `cram_filter_align_bwamem2_fixmate_sort`       | -             |                            |
| ^ ( samtools + bwamem2 ) ^                   | 1.17 + 2.2.1  | -                          |
| `cram_filter_minimap2_filter5end_fixmate_sort` | -             |                            |
| ^ ( samtools + minimap2 ) ^                  | 1.17 + 2.24   | -                          |
| `custom_dumpsoftwareversions`                  | -             | Python 3.11.7 + yaml 5.4.1 |
| `extract_cov_id` ( coreutils )                 | 9.1           | 9.3                        |
| `extract_repeat` ( perl )                      | 5.26.2        | -                          |
| `extract_telo` ( coreutils )                   | -             | 9.1                        |
| `find_telomere_regions` ( gcc )                | 7.1.0         | 7.1.0 + 1.0                |
| `find_telomere_windows` ( java-jdk )           | 8.0.112       | 8.0.112 + 1.0              |
| `findhalfcoverage` ( python )                  | -             | Python 3.9.1 + 1.0         |
| `gap_length` ( coreutils )                     | 9.1           | -                          |
| `generate_cram_csv` ( samtools )               | 1.17          | -                          |
| `generate_genome_file` (coreutils) | 9.1 | - |
| `get_largest_scaff` ( coreutils )              | 9.1           | -                          |
| `getminmaxpunches` ( coreutils )               | 9.1           | -                          |
| `graphoverallcoverage` ( perl )                | -             | 5.26.2 + 1.0               |
| `gnu-sort`                                     | 8.25          | 9.3                        |
| `longreadcoveragescalelog`                     | -             | Python 3.9.1 + 1.0         |
| `minimap2` + `samtools` (align, map)             |               | 2.28-r1209 + 1.20          |
| `pretextmap` + `samtools`                        | 0.1.9 + 1.18  | 0.1.9\* + 1.20             |
| `pretextgraph`                                 | 0.0.4         | 0.0.6                      |
| `pretextsnapshot` + `UCSC`                       | 0.0.6b + 447  | 0.0.4 (official version)   |
| `rename_ids` ( coreutils )                     | -             | 9.1                        |
| `reformat_intersect` ( coreutils )             | -             | 9.1                        |
| `replace_dots` ( coreutils )                   | -             | 9.1                        |
| `seqtk`                                        | 1.4           | 1.4-r122                   |
| `samtools` (faidx,merge,sort,view)             | 1.18          | 1.21                       |
| `ucsc`                                         | 445           | 469                        |
| `windowmasker` (blast)                         | -             | 2.14.0 + 1.0.0             |

Even modules which have not had a version bump have indeed been updated through NF-core to remove defaults.

Some modules now have two versions, the new addition is the script version rather than just the dependency version.

## [[1.0.1](https://github.com/sanger-tol/curationpretext/releases/tag/1.0.1)] - UNSC Cradle H1 - [2024-10-24]

## Added

- Ability for end users to select "sorted" or "unsorted" (default) for the pretext maps.
- Adds a container for find_telomere.

### Paramters

| Old Version | New Versions |
| ----------- | ------------ |
|             | --map_order  |

### Software Dependencies

No updates to dependency versions

### Dependencies

### Deprecated

## [[1.0.0](https://github.com/sanger-tol/curationpretext/releases/tag/1.0.0)] - UNSC Cradle - [2024-02-22]

### Added

- Subworkflows for both minimap2 and bwamem2 mapping.
- Subworkflow for Pretext accessory file ingestion.
- Considerations for other longread datatypes

### Paramters

| Old Version | New Versions    |
| ----------- | --------------- |
|             | --aligner       |
|             | --longread_type |
| --pacbio    | --longread      |

### Software Dependencies

Note, since the pipeline is using Nextflow DSL2, each process will be run with its own Biocontainer. This means that on occasion it is entirely possible for the pipeline to be using different versions of the same tool. However, the overall software dependency changes compared to the last release have been listed below for reference.

| Module                                                              | Old Version    | New Versions   |
| ------------------------------------------------------------------- | -------------- | -------------- |
| bamtobed_sort ( bedtools + samtools )                               | -              | 2.31.0 + 1.17  |
| bedtools ( genomecov, bamtobed, intersect, map, merge, makewindows) | 2.31.0         | 2.31.1         |
| bwamem2 index                                                       | -              | 2.2.1          |
| cram_filter_align_bwamem2_fixmate_sort                              | -              |                |
| ^ ( samtools + bwamem2 ) ^                                          | 1.16.1 + 2.2.1 | 1.17 + 2.2.1   |
| cram_filter_minimap2_filter5end_fixmate_sort                        | -              |                |
| ^ ( samtools + minimap2 ) ^                                         | -              | 1.17 + 2.24    |
| extract_cov_id ( coreutils )                                        | -              | 9.1            |
| extract_repeat ( perl )                                             | -              | 5.26.2         |
| extract_telo ( coreutils )                                          | -              | 9.1            |
| find_telomere_regions ( gcc )                                       | -              | 7.1.0          |
| find_telomere_windows ( java-jdk )                                  | -              | 8.0.112        |
| gap_length ( coreutils )                                            | -              | 9.1            |
| generate_cram_csv ( samtools )                                      | -              | 1.17           |
| get_largest_scaff ( coreutils )                                     | -              | 9.1            |
| gnu-sort                                                            | -              | 8.25           |
| pretextmap + samtools                                               | 0.1.9 + 1.17   | 0.1.9\* + 1.18 |
| pretextgraph                                                        |                | 0.0.4          |
| pretextsnapshot + UCSC                                              | 0.0.6 + 447    | 0.0.6b + 447   |
| seqtk                                                               | -              | 1.4            |
| samtools (faidx,merge,sort,view)                                    | 1.17           | 1.18           |
| tabix                                                               | -              | 1.11           |
| ucsc                                                                | 377            | 445            |
| windowmasker (blast)                                                | -              | 2.14.0         |

- This version has been modified by @yumisims inorder to expose the texture buffer variable

### Dependencies

### Deprecated

## [[0.1.0](https://github.com/sanger-tol/curationpretext/releases/tag/0.1.0)] - UNSC Infinity - [2023-10-02]

Initial release of sanger-tol/curationpretext, created with the [sager-tol](https://nf-co.re/) template.

### Added

- Subworkflow to generate tracks containing telomeric sites.
- Subworkflow to generate Pretext maps and images
- Subworkflow to generate repeat density tracks.
- Subworkflow to generate longread coverage tracks from pacbio data.
- Subworkflow to generate gap tracks.

### Parameters

| Old Version | New Versions |
| ----------- | ------------ |
|             | --input      |
|             | --cram       |
|             | --pacbio     |
|             | --sample     |
|             | --teloseq    |
|             | -entry       |

### Software Dependencies

Note, since the pipeline is using Nextflow DSL2, each process will be run with its own Biocontainer. This means that on occasion it is entirely possible for the pipeline to be using different versions of the same tool. However, the overall software dependency changes compared to the last release have been listed below for reference.

| Module                                 | Old Version | New Versions   |
| -------------------------------------- | ----------- | -------------- |
| bamtobed_sort ( bedtools + samtools )  | -           | 2.31.0 + 1.17  |
| bedtools                               | -           | 2.31.0         |
| cram_filter_align_bwamem2_fixmate_sort | -           |                |
| ^ ( samtools + bwamem2 ) ^             | -           | 1.16.1 + 2.2.1 |
| extract_cov_id ( coreutils )           | -           | 9.1            |
| extract_repeat ( perl )                | -           | 5.26.2         |
| extract_telo ( coreutils )             | -           | 9.1            |
| find_telomere_regions ( gcc )          | -           | 7.1.0          |
| find_telomere_windows ( java-jdk )     | -           | 8.0.112        |
| gap_length ( coreutils )               | -           | 9.1            |
| generate_cram_csv ( samtools )         | -           | 1.17           |
| get_largest_scaff ( coreutils )        | -           | 9.1            |
| gnu-sort                               | -           | 8.25           |
| pretextmap + samtools                  | -           | 0.1.9 + 1.17   |
| seqtk                                  | -           | 1.4            |
| tabix                                  | -           | 1.11           |
| ucsc                                   | -           | 377            |
| windowmasker (blast)                   | -           | 2.14.0         |

### Fixed

### Dependencies

### Deprecated
