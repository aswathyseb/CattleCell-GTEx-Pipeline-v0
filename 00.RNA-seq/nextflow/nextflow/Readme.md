# Setup: CattleCell-GTEx RNA-seq pipeline on Linux 

This repository if a fork from FarmGTEx [CattleCell-GTEx-Pipeline-v0](https://github.com/FarmGTEx/CattleCell-GTEx-Pipeline-v0) analysis repo. 

The RNA-seq Nextflow lives in `00.RNA-seq/nextflow/nextflow`. It is not a turnkey pipeline: paths, SLURM, and a conda env are hardcoded for their cluster.

Described below are the set-up instructions and the changes that were made to the original code.

## 1. Clone and go to the RNA-seq folder

```bash
git clone git@github.com:aswathyseb/CattleCell-GTEx-Pipeline-v0.git
cd CattleCell-GTEx-Pipeline-v0/00.RNA-seq/nextflow/nextflow
```

## 2. Create a micromamba environment and add tools

`nf-farmgtex.yml` is a 2023 locked conda export (`defaults` channel, pinned builds, prefix `/home/huicongz/miniconda3/envs/nf-farmgtex`).  `nf-farmgtex.yml` file is  not used here, instead a new environment is created and tools are added.

Install the tools part 1 with the following commands:

```bash

# Create an environment
micromamba create -y -n nf-cattlegtex

# Activate the environment
micromamaba activate nf-cattlegtex

# Install tools
micromamba install -y -n nf-farmgtex \
  -c conda-forge -c bioconda \
  nextflow star fastp salmon samtools gatk4 picard \
  bedtools bcftools htslib subread stringtie htseq regtools \
  python=3.10 pysam r-base
```

Check if tools are installed properly

```bash
nextflow -version
STAR --version
```

Additional tool binaries are downloaded with `download.sh`. See below.

## 3. Point Nextflow at this machine, not SLURM

`nextflow.config` originally has `executor = 'slurm'`, `--account=farmgtex`, and their conda prefix. 

For a local Linux box, replace it with:

```groovy
process {
    executor = 'local'
    errorStrategy = 'retry'
}

conda.enabled = false
```

`conda.enabled = false` makes Nextflow ignore those hardcoded conda prefixes. The tasks then use whatever is on PATH, so start Nextflow only after `micromamba activate nf-cattlegtex`.

