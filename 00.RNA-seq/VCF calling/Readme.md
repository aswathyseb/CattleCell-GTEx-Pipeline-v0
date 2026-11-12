
## Phased VCF generation

The steps in this folder uses GLIMPSE2 to create a phased VCF file.

I have generated a Makefile including all the steps (`phased_vcf.mk`)

The `phased_vcf.mk` uses two micromamba environments, activated from ${HOME}/.local/bin/micromamba with root prefix ${HOME}/micromamba.

* Step 1 	: nf-cattlegtex
* Steps 2-5 : glimpse2

### Glimpse2 environment

```bash
micromamba create -y -n glimpse2 -c conda-forge -c bioconda 'glimpse-bio>=2'
micromamba activate glimpse2
micromamba install -n glimpse2 -c conda-forge -c bioconda bcftools
micromamba install -n glimpse2 -c conda-forge python click
```

GLIMPSE2 links against its own htslib and bcftools.

Putting it in nf-cattlegtex can make the solver upgrade the samtools, bcftools, and htslib already in that environment and change the RNA-seq run.


### How to run
```bash
# Step1
time make -f phased_vcf.mk step1_preprocessing_panel -j 12
# Step2
time make -f phased_vcf.mk step2_split_and_chunking_panel -j 12
# Step3
time make -f phased_vcf.mk step3_imputation_per_bin -j 4
# Step 4
time make -f phased_vcf.mk -j 4 step4_merge_bins
```

