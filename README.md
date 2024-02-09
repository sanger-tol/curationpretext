# ![sanger-tol/curationpretext](docs/images/nf-core-curationpretext_logo_light.png#gh-light-mode-only) ![sanger-tol/curationpretext](docs/images/nf-core-curationpretext_logo_dark.png#gh-dark-mode-only)

[![AWS CI](https://img.shields.io/badge/CI%20tests-full%20size-FF9900?labelColor=000000&logo=Amazon%20AWS)](https://nf-co.re/curationpretext/results)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.XXXXXXX-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.XXXXXXX)

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A522.10.1-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Nextflow Tower](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Nextflow%20Tower-%234256e7)](https://tower.nf/launch?pipeline=https://github.com/sanger-tol/curationpretext)

[![Get help on Slack](http://img.shields.io/badge/slack-nf--core%20%23curationpretext-4A154B?labelColor=000000&logo=slack)](https://nfcore.slack.com/channels/curationpretext)[![Follow on Twitter](http://img.shields.io/badge/twitter-%40nf__core-1DA1F2?labelColor=000000&logo=twitter)](https://twitter.com/nf_core)[![Follow on Mastodon](https://img.shields.io/badge/mastodon-nf__core-6364ff?labelColor=FFFFFF&logo=mastodon)](https://mstdn.science/@nf_core)[![Watch on YouTube](http://img.shields.io/badge/youtube-nf--core-FF0000?labelColor=000000&logo=youtube)](https://www.youtube.com/c/nf-core)

## Introduction

**sanger-tol/curationpretext** is a bioinformatics pipeline typically used in conjunction with [TreeVal](https://github.com/sanger-tol/treeval) to generate pretext maps (and optionally telomeric, gap, coverage, and repeat density plots which can be ingested into pretext) for the manual curation of high quality genomes.

This is intended as a supplementary pipeline for the [treeval](https://github.com/sanger-tol/treeval) project. This pipeline can be simply used to generate pretext maps, information on how to run this pipeline can be found in the [usage documentation](https://pipelines.tol.sanger.ac.uk/curationpretext/usage).

<!-- TODO nf-core: Include a figure that guides the user through the major workflow steps. Many nf-core
     workflows use the "tube map" design for that. See https://nf-co.re/docs/contributing/design_guidelines#examples for examples.   -->

1. Generate Maps - Generates pretext maps as well as a static image.

2. Accessory files - Generates the repeat density, gap, telomere, and coverage tracks.

## Usage

> **Note**
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how
> to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline)
> with `-profile test` before running the workflow on actual data.

Currently, the pipeline uses the following flags:

- `--input`

  - The absolute path to the assembled genome in, e.g., `/path/to/assembly.fa`

- `--longread`

  - The directory of the fasta files generated from longread reads, e.g., `/path/to/fasta/`

- `--longread_type`

  - The type of longread data you are utilising, e.g., ont, illumina, hifi.

- `--aligner`

  - The aligner yopu wish to use for the coverage generation, defaults to bwamem2 but minimap2 is also supported.

- `--cram`

  - The directory of the cram _and_ cram.crai files, e.g., `/path/to/cram/`

- `--teloseq`

  - A telomeric sequence, e.g., `TTAGGG`

- `-entry`
  - ALL_FILES generates all accessory files as well as pretext maps
  - MAPS_ONLY generates only the pretext maps and static images

Now, you can run the pipeline using:

<!-- TODO nf-core: update the following command to include all required parameters for a minimal example -->

```bash
// For ALL_FILES run
```bash
nextflow run sanger-tol/curationpretext \
  --input { input.fasta } \
  --cram { path/to/cram/ } \
  --longread { path/to/longread/fasta/ } \
  --longread_type { default is "hifi" }
  --sample { default is "pretext_rerun" } \
  --teloseq { deafault is "TTAGGG" } \
  --outdir { OUTDIR } \
  -profile <docker/singularity/{institute}> \

// For MAPS_ONLY run
nextflow run sanger-tol/curationpretext \
  --input { input.fasta } \
  --cram { path/to/cram/ } \
  --longread { path/to/longread/fasta/ } \
  --longread_type { default is "hifi" }
  --sample { default is "pretext_rerun" } \
  --teloseq { deafault is "TTAGGG" } \
  --outdir { OUTDIR } \
  -profile <docker/singularity/{institute}> \
  -entry MAPS_ONLY \
```
```

> **Warning:**
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those
> provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_;

For more details, please refer to the [usage documentation](https://pipelines.tol.sanger.ac.uk/curationpretext/usage) and the [parameter documentation](https://pipelines.tol.sanger.ac.uk/curationpretext/parameters).

## Pipeline output

To see the the results of a test run with a full size dataset refer to the [results](https://pipelines.tol.sanger.ac.uk/curationpretext/results) tab on the nf-core website pipeline page.
For more details about the output files and reports, please refer to the
[output documentation](https://pipelines.tol.sanger.ac.uk/curationpretext/output).

## Credits

sanger-tol/curationpretext was originally written by Damon-Lee B Pointon (@DLBPointon).

We thank the following people for their extensive assistance in the development of this pipeline:

- @yumisims

- @weaglesBio

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

For further information or help, don't hesitate to get in touch on the [Slack `#curationpretext` channel](https://nfcore.slack.com/channels/curationpretext) (you can join with [this invite](https://nf-co.re/join/slack)).

## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use  sanger-tol/curationpretext for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

You can cite the `nf-core` publication as follows:

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
