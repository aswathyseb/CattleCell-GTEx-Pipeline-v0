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
micromamba install -y -n nf-cattlegtex \
  -c conda-forge -c bioconda \
  nextflow star fastp fastqc multiqc salmon samtools gatk4 picard \
  bedtools bcftools htslib subread stringtie htseq regtools \
  python=3.10 pysam r-base
```

Check if tools are installed properly

```bash
nextflow -version
STAR --version
```

Additional tool binaries are downloaded with `download.sh`. See below.

## 3. Point Nextflow at local machine, not SLURM

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


## 4. Set the paths

Hardcoded paths to change:

| File | What to set |
| --- | --- |
| `download.sh` | `workpath="..."` (parent for `tools/` and `cattle_genome/`) |
| `script/prepare.nf` | `params.workpath` |
| `script/rna.nf` | `params.workpath`, `params.input` (FASTQ root), `params.suffix` (e.g. `.fastq.gz`) |

Use one work directory, for example `$HOME/cattlecell`:

```text
cattlecell/
  tools/
  cattle_genome/          # FASTA, GTF, VCF, STAR/Salmon indexes
  samplelist.csv
  result_new/
```

* The workflow expects FASTQs in a **nested** layout `{params.input}/{sampleID}/*{suffix}`. 

```text
fastqfile/
  SAMPLE1/*.fastq.gz
  SAMPLE2/*.fastq.gz
```

* Modify`params.suffix` as `.fq.gz` if files end in `.fq.gz`.


* The `samplelist.csv` file is a tab-delimied file with no header. The first column with sampleID is the only required field.

```text
T011425-6	Mammary Gland
T050725-1	Liver
```
Sample IDs must match folder names and have no FASTQ suffix.

## 5. Download references and extra tools

Edit `workpath` in `download.sh`, then:

```bash
bash download.sh
```

That pulls Ensembl 108 cattle FASTA/GTF/cDNA/VCF plus the extra tools.

### Tool versions

These are the tool binaries that `download.sh` fetches into `tools/`.

| Tool | Original pipeline | Current |
| --- | --- | --- |
| OSCA | 0.46.1 | 1.22 |
| DaPars2 | git `master` | release v2.1 |
| SalmonTools | git `master` | git `master` (no release) |
| UCSC `gtfToGenePred`, `genePredToBed` | unversioned daily build | unversioned daily build |
| REDItools | git `master` | release REDItoolsFamily_V1.0 |
| leafcutter | git `master` | git `master` (no release) |
| TEdetectionEvaluation | git `main` | git `main` (no release) |

**Notes**

**1.OSCA** : Modify `transcript.nf` to call the current 1.22 build of OSCA.

**2. Enhancer counts**
The original readme wants `bosTau9_E6.bed` (and they mention a “file folder”) copied into `cattle_genome/` before `prepare.nf`. That bed is not in the public tree; without it the enhancer step cannot run. 

STAR/Salmon/featureCounts do not need it. `enhancer(STAR.out.bam)` in `rna.nf` is commented out so that the work flow can continue without it.

## 6. Build indexes (`prepare.nf`)

```bash
pixi run nextflow run script/prepare.nf -c nextflow.config -resume -w ./work
```

`-w` is Nextflow’s scratch directory. It is not `params.workpath`. If you omit `-w`, Nextflow creates `./work` in the launch directory.

The `prepare.nf` calls `fastadic`, `chr`, `snpdb`, `RNAstablity`, `UTR`, `STARINDEX`, and `SALMONINDEX`. 


### Salmon 2.0 decoy index

Pixi installs Salmon **2.0** (Rust rewrite). FarmGTEx’s original `SALMONINDEX` called [SalmonTools](https://github.com/COMBINE-lab/SalmonTools) `generateDecoyTranscriptome.sh`, which needs **mashmap** and was written for C++ Salmon 1.x. That script is not part of Salmon 2.0. Without mashmap it fails with:

```text
generateDecoyTranscriptome.sh: line 105: mashmap: command not found
```

Salmon 2.0 still supports decoy-aware indexes via `-d` / `--decoys`. `SALMONINDEX` now builds the index the way the 2.0 docs describe (whole genome as decoys; no mashmap, no SalmonTools):

```bash
grep '^>' genome.fa | cut -d ' ' -f 1 | sed 's/>//' > decoys.txt
cat transcriptome.fa genome.fa > gentrome.fa
salmon index -t gentrome.fa -d decoys.txt -p 16 -i indexsalmon
```

Documentation:

- [Salmon 2.0 — Decoy-aware indexing](https://combine-lab.github.io/salmon/getting-started/quick-start/)

Salmon 2.0 cannot read a 1.x (pufferfish) index. Rebuild with 2.0. In `script/module/transcript.nf`, `--validateMappings` is accepted but ignored (selective alignment is the default).

To match FarmGTEx’s original stack instead (Salmon 1.10 + mashmap script):

```bash
pixi add mashmap 'salmon=1.10'
```

and restore the `generateDecoyTranscriptome.sh` command in `SALMONINDEX`.



## 7. Run RNA-seq part 1 (`rna.nf`)

```bash
nextflow run script/rna.nf -resume -w ./work
```

The workflow reads 
- samplelist.csv 
- data directory
- reference directory

and other input files through `params.` specified at the start of `rna.nf`. Modify these if needed.

That runs FastP → STAR + Salmon → gene/exon/RNA counts → BQSR → lncRNA. TE and RNA-editing modules exist but are not in the current workflow.

**Enhancer counts are commented out** in `script/rna.nf` (`// enhancer(STAR.out.bam)`). `featureCounts` needs `cattle_genome/enhancer.saf`, which FarmGTEx ships in a private “file folder” (source bed `bosTau9_E6.bed`). Neither file is in the public repo or in `download.sh`. Without them the `enhancer` process exits 255. Uncomment that line after you copy `enhancer.saf` into `cattle_genome/`.


### Nextflow 26 patches in the modules

These were required before `rna.nf` would even launch on Nextflow 26.04.6:

- Nextflow 26 rejects `publishDir` inside an `output:` block. 
`STARINDEX`, `SALMONINDEX`, and `TE_index` were patched so `publishDir` is a process directive.

- Process directives cannot use `=`. Change `memory = '16 GB'` to `memory '16 GB'` (same for `cpus` and `time`) in `expression.nf`, `transcript.nf`, `bqsr.nf`, and `LNCRNA.nf`.

- `publishDir` paths that interpolate `${sampleID}` must be closures, or Nextflow evaluates `sampleID` at parse time and errors (`No such variable: sampleID`):

  ```groovy
  publishDir mode: 'copy', path: { "${params.outpath}/${sampleID}/QC/" }, pattern: '*json'
  ```

- `RNAedit.nf` had a typo: `${sample}` → `${sampleID}`. Nextflow still compiles included modules even when `RNAEDIT` is not called from the workflow.

- `conda '/home/huicongz/...'` lines can stay. With `conda.enabled = false` they are ignored; tools come from pixi. `time` is a SLURM wall-time and is not enforced by the local executor. `memory` / `cpus` still limit how many local tasks run at once. Hardcoded `--thread 8` inside FastP does not follow `cpus`.

## Other changes in the scripts to include additional output files

*`fastp.nf`: pattern: '*json' is removed from publishDir so all output files are accessible



## 8. Later steps (only after part 1)

VCF calling is in `00.RNA-seq/VCF calling` and needs the CattleGTEx reference panel. Then `script/rna2.nf` uses the imputed VCF for WASP / mapping-bias correction. Skip this until part 1 finishes.

## Tool versions: nf-farmgtex.yml vs nf-cattlegtex.yml

`nf-cattlegtex.yml` is an export of the micromamba environment `nf-cattlegtex` (`micromamba env export -n nf-cattlegtex --no-builds`), with the local prefix removed. `nf-farmgtex.yml` is the 2023 FarmGTEx lock. The table lists workflow tools whose versions differ.

| Tool | nf-farmgtex.yml | nf-cattlegtex.yml |
| --- | --- | --- |
| bcftools | 1.17 | 1.24 |
| bedtools | 2.31.0 | 2.31.1 |
| fastp | 0.23.3 | 1.3.7 |
| fastqc | not installed | 0.12.1 |
| gatk4 | 4.3.0.0 | 4.6.2.0 |
| glimpse | 4.18.7 | not installed |
| htseq | 2.0.3 | 2.1.2 |
| htslib | 1.17 | 1.24 |
| mashmap | 3.0.4 | not installed |
| multiqc | not installed | 1.35 |
| nextflow | 22.10.6 | 26.04.6 |
| OSCA | 0.46.1 | 1.22 |
| picard | 3.0.0 | 3.5.0 |
| plink | 1.90b6.21 | not installed |
| pysam | 0.21.0 | 0.24.0 |
| python | 3.10.8 | 3.10.21 |
| r-base | 4.2.2 | 4.4.1 |
| r-leafcutter | 0.2 | not installed |
| salmon | 1.10.1 | 2.7.0 |
| samtools | 1.3.1 | 1.24 |
| star | 2.7.10b | 2.7.11b |
| stringtie | 2.2.1 | 3.0.3 |
| subread | 2.0.3 | 2.1.1 |
| vcftools | 0.1.16 | not installed |

