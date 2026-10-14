# Phased VCF calling (GLIMPSE2)
# Commands match CattleCell-GTEx-Pipeline-v0/00.RNA-seq/VCF calling/step*.sh
#
# REF_PATH  path to the reference panel (step1, step2)
# VCF_PATH  path to imputed VCF files (step4, step5)
# CHR       chromosome for step4
# BIN       imputation bin for step3

SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -ec
.PHONY: usage step1_preprocessing_panel step2_split_and_chunking_panel step3_imputation_per_bin step4_merge_bins step5_merge_chromosomes

REF_PATH ?= v0_rnaseq/cattle_genome/imputation_panel/beagle/CattleSNPs
VCF_PATH ?=
CHR ?=
BIN ?=
BAMS ?= v0_rnaseq/UCD1.2/bqsr_bamlist
OUT ?= v0_rnaseq/UCD1.2/vcf

# Step 1 uses the cattle GTEx nextflow environment.
NF_ENV = nf-cattlegtex

# Steps 2-5 use the GLIMPSE2 environment.
GLIMPSE2_ENV = glimpse2

# Make does not source ~/.bashrc, so micromamba is not on PATH there.
MAMBA_EXE = $(HOME)/.local/bin/micromamba
MAMBA_ROOT_PREFIX = $(HOME)/micromamba

# Activate $(1) for every command in the current target.
# .ONESHELL keeps this shell, so the activation is not repeated per command.
define activate
eval "$$($(MAMBA_EXE) shell hook --shell bash --root-prefix $(MAMBA_ROOT_PREFIX))"
micromamba activate $(1)
endef


usage:
	@echo "Usage: make -f phased_vcf.mk <target>"
	@echo "  step1_preprocessing_panel       REF_PATH=...  (make -j N)"
	@echo "  step2_split_and_chunking_panel  REF_PATH=..."
	@echo "  step3_imputation_per_bin        BIN=..."
	@echo "  step4_merge_bins                VCF_PATH=... CHR=..."
	@echo "  step5_merge_chromosomes         VCF_PATH=..."

#
# step1 Preprocessing the genotyping imputation panel
# One output file per input VCF. Run with make -j to process files in parallel.
# make -f phased_vcf.mk -j 8 step1_preprocessing_panel
#
PANEL_VCFS = $(filter-out $(REF_PATH)/AN_AC.%,$(wildcard $(REF_PATH)/*.vcf.gz))
PANEL_TAGGED = $(patsubst $(REF_PATH)/%.vcf.gz,$(REF_PATH)/AN_AC.%.vcf.gz,$(PANEL_VCFS))

step1_preprocessing_panel: $(PANEL_TAGGED)

$(REF_PATH)/AN_AC.%.vcf.gz: $(REF_PATH)/%.vcf.gz
	$(call activate,${NF_ENV})
	tabix -p vcf $<
	bcftools +fill-tags -Oz -o $@ -- $< -t AN,AC
	bcftools index $@

#
# step2 Chunking and splitting the phased reference panel for GLIMPSE2 imputation
#
step2_split_and_chunking_panel:
	$(call activate,${GLIMPSE2_ENV})
	cd ${REF_PATH}
	ls AN_AC*.vcf.gz | sed -n 's/^AN_AC\.\(.*\)\.phased\.vcf\.gz$$/\1/p' | grep -v '^AN_AC\.' > chrlist.txt
	mkdir -p split
	cat chrlist.txt | while read chr
	do
	GLIMPSE2_chunk --input AN_AC.$${chr}.phased.vcf.gz --region $${chr} --window-mb 5.0 --buffer-mb 1.0 --output chunks.$${chr}.txt --sequential --threads 12
	while IFS="" read -r LINE || [ -n "$$LINE" ];
	do
	printf -v ID "%02d" $$(echo $$LINE | cut -d" " -f1)
	    IRG=$$(echo $$LINE | cut -d" " -f3)
	    ORG=$$(echo $$LINE | cut -d" " -f4)
	    GLIMPSE2_split_reference --reference ${REF_PATH}/AN_AC.$${chr}.phased.vcf.gz --input-region $${IRG} --output-region $${ORG} --output ./split/split
	done < chunks.$$chr.txt
	done
	cd ${REF_PATH}/split/
	for bin in `ls -1v split_*.bin` ; do basename $$bin .bin ; done | sed 's/^split\_//g' > bins.txt

#
# step3 Perform genotype imputation per bin using GLIMPSE2
#
step3_imputation_per_bin:
	$(call activate,${GLIMPSE2_ENV})
	cd ${BAMS}
	ls *.bam > bamlist
	GLIMPSE2_phase \
	            --bam-list ./bamlist --reference /faststorage/project/farmgtex/gtex/cattle_ref/SNPs/split/split_${BIN}.bin \
	            --output ${OUT}/${BIN}.bcf --threads 12

#
# step4 Merge imputed bins into chromosome-wide VCFs and filter variants
#
step4_merge_bins:
	$(call activate,${GLIMPSE2_ENV})
	cd ${VCF_PATH}
	ls -1v  ${CHR}_*.bcf >  ${CHR}.txt
	        GLIMPSE2_ligate \
	            --input ${CHR}.txt \
	            --output impute${CHR}.bcf \
	            --threads 12
	 python3 recalINFO.py --invcf impute${CHR}.bcf > recal_${CHR}.vcf
	 bgzip -f recal_${CHR}.vcf
	 tabix -p vcf recal_${CHR}.vcf.gz
	 bcftools annotate -x ID,FORMAT/GP,FORMAT/DS,INFO/RAF  -O b -o recal.simplified_${CHR}.bcf recal_${CHR}.vcf --threads 12
	 bcftools view -i 'INFO > 0.6 & AF > 0.05 & AF < 0.95' recal.simplified_${CHR}.bcf -O b -o recal.simplified_filter_${CHR}.bcf --threads 12
	 bcftools index recal.simplified_filter_${CHR}.bcf

#
# step5 Merge all filtered chromosome-wide VCF files
#
step5_merge_chromosomes:
	$(call activate,${GLIMPSE2_ENV})
	cd ${VCF_PATH}
	ls -1v   recal.simplified_filter_*.bcf >  impute.txt
	GLIMPSE2_ligate \
	          --input impute.txt \
	          --output recal.final.bcf \
	          --threads 12
