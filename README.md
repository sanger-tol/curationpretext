# ![sanger-tol/curationpretext](docs/images/curationpretext-light.png#gh-light-mode-only) ![sanger-tol/curationpretext](docs/images/curationpretext-dark.png#gh-dark-mode-only)

[![GitHub Actions CI Status](https://github.com/sanger-tol/curationpretext/workflows/nf-core%20CI/badge.svg)](https://github.com/sanger-tol/curationpretext/actions?query=workflow%3A%22nf-core+CI%22)
[![GitHub Actions Linting Status](https://github.com/sanger-tol/curationpretext/workflows/nf-core%20linting/badge.svg)](https://github.com/sanger-tol/curationpretext/actions?query=workflow%3A%22nf-core+linting%22)[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.12773958-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.12773958)

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A524.04.2-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Seqera Platform](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Seqera%20Platform-%234256e7)](https://cloud.seqera.io/launch?pipeline=https://github.com/sanger-tol/curationpretext)

## Introduction

**sanger-tol/curationpretext** is a bioinformatics pipeline typically used in conjunction with [TreeVal](https://github.com/sanger-tol/treeval) to generate pretext maps (and optionally telomeric, gap, coverage, and repeat density plots which can be ingested into pretext) for the manual curation of high quality genomes.

This is intended as a supplementary pipeline for the [treeval](https://github.com/sanger-tol/treeval) project. This pipeline can be simply used to generate pretext maps, information on how to run this pipeline can be found in the [usage documentation](https://pipelines.tol.sanger.ac.uk/curationpretext/usage).

![Workflow Diagram](./docs/images/CurationPretext_1_3_0.png)

1. Generate Maps - Generates pretext maps as well as a static image.

2. Accessory files - Generates the repeat density, gap, telomere, and coverage tracks.

## Usage

> [!NOTE]
> If you are new to Nextflow and nf-core, please refer to [this page](https://nf-co.re/docs/usage/installation) on how to set-up Nextflow. Make sure to [test your setup](https://nf-co.re/docs/usage/introduction#how-to-run-a-pipeline) with `-profile test` before running the workflow on actual data.

Currently, the pipeline uses the following flags:

- `--input`

  - The absolute path to the assembled genome in, e.g., `/path/to/assembly.fa`

- `--reads`

  - The directory of the fasta files generated from longread reads, e.g., `/path/to/fasta/`

- `--read_type`

  - The type of longread data you are utilising, e.g., ont, illumina, hifi.

- `--aligner`

  - The aligner yopu wish to use for the coverage generation, defaults to bwamem2 but minimap2 is also supported.

- `--cram`

  - The directory of the cram _and_ cram.crai files, e.g., `/path/to/cram/`

- `--map_order`

  - hic map scaffold order, input either `length` or `unsorted`

- `--teloseq`

  - A telomeric sequence, e.g., `TTAGGG`

- `--all_output`

  - An option to output all maps + accessory files, the default will only output the pretextmaps where ingestion has occured.

Now, you can run the pipeline using:

```bash
nextflow run sanger-tol/curationpretext \
  --input { input.fasta } \
  --cram { path/to/cram/ } \
  --reads { path/to/longread/fasta/ } \
  --read_type { default is "hifi" }
  --sample { default is "pretext_rerun" } \
  --teloseq { default is "TTAGGG" } \
  --map_order { default is "unsorted" } \
  --all_output <true/false> \
  --outdir { OUTDIR } \
  -profile <docker/singularity/{institute}>

```

> **Warning:**
> Please provide pipeline parameters via the CLI or Nextflow `-params-file` option. Custom config files including those
> provided by the `-c` Nextflow option can be used to provide any configuration _**except for parameters**_;

For more details, please refer to the [usage documentation](https://pipelines.tol.sanger.ac.uk/curationpretext/usage) and the [parameter documentation](https://pipelines.tol.sanger.ac.uk/curationpretext/parameters).

## Pipeline output

To see the the results of a test run with a full size dataset refer to the [results](https://pipelines.tol.sanger.ac.uk/curationpretext/results) tab on the sanger-tol/curationpretext website pipeline page.
For more details about the output files and reports, please refer to the
[output documentation](https://pipelines.tol.sanger.ac.uk/curationpretext/output).

## Credits

sanger-tol/curationpretext was originally written by Damon-Lee B Pointon (@DLBPointon).

We thank the following people for their extensive assistance in the development of this pipeline:

- @muffato - For reviews.

- @yumisims - TreeVal and Software.

- @weaglesBio - TreeVal and Software.

- @josieparis - Help with better docs and testing.

- @mahesh-panchal - Large support with 1.2.0 in making the pipeline more robust with other HPC environments.

- @GRIT - For feedback and feature requests.

- @prototaxites - Support with 1.3.0 and showing me the power of GAWK.

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

## Citations

If you use sanger-tol/curationpretext for your analysis, please cite it using the following doi: [10.5281/zenodo.12773958](https://doi.org/10.5281/zenodo.12773958)

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/main/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
