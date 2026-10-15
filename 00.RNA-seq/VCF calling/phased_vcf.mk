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

REF_PATH ?= cattle_genome/imputation_panel/beagle/CattleSNPs
VCF_PATH ?=
CHR ?=
BIN ?= 1_1_6025375
BAMS ?= UCD1.2/bqsr_bamlist
OUT ?= UCD1.2/vcf

# Step 1 uses the cattle GTEx nextflow environment.
NF_ENV = nf-cattlegtex

# Steps 2-5 use the GLIMPSE2 environment.
GLIMPSE2_ENV = glimpse2

# Make does not source ~/.bashrc, so micromamba is not on PATH there.
MAMBA_EXE = ${HOME}/.local/bin/micromamba
MAMBA_ROOT_PREFIX = ${HOME}/micromamba

# Activate ${1} for every command in the current target.
# .ONESHELL keeps this shell, so the activation is not repeated per command.
define activate
eval "$$(${MAMBA_EXE} shell hook --shell bash --root-prefix ${MAMBA_ROOT_PREFIX})"
micromamba activate ${1}
endef


usage:
	@echo "Usage: make -f phased_vcf.mk <target>"
	@echo "  step1_preprocessing_panel       REF_PATH=...  (make -j N)"
	@echo "  step2_split_and_chunking_panel  REF_PATH=..."
	@echo "  step2_split_and_chunking_panel_parallel  REF_PATH=...  (make -j N)"
	@echo "  step3_imputation_per_bin        BIN=..."
	@echo "  step3_imputation_per_bin_parallel   (make -j N; each job uses 12 threads)"
	@echo "  step4_merge_bins                VCF_PATH=... CHR=..."
	@echo "  step5_merge_chromosomes         VCF_PATH=..."

#
# Step1 Preprocessing the genotyping imputation panel.
# Adds AN and AC tags to the reference VCFs.
# One output file per input VCF. Run with make -j to process files in parallel.
# make -f phased_vcf.mk -j 8 step1_preprocessing_panel
#
PANEL_VCFS = $(filter-out ${REF_PATH}/AN_AC.%,$(wildcard ${REF_PATH}/*.vcf.gz))
PANEL_TAGGED = $(patsubst ${REF_PATH}/%.vcf.gz,${REF_PATH}/AN_AC.%.vcf.gz,${PANEL_VCFS})

check:
	@echo "PANEL_VCFS: ${PANEL_VCFS}"
	@echo "PANEL_TAGGED: ${PANEL_TAGGED}"

step1_preprocessing_panel: ${PANEL_TAGGED}

${REF_PATH}/AN_AC.%.vcf.gz: ${REF_PATH}/%.vcf.gz
	$(call activate,${NF_ENV})
	tabix -p vcf $<
	bcftools +fill-tags -Oz -o $@ -- $< -t AN,AC
	bcftools index $@


#
# Step2 in parallel: one chromosome per job.
# Divide the chromosome into chunks and create binary bins.
# make -f phased_vcf.mk -j 3 step2_split_and_chunking_panel_parallel
#
TAGGED_VCFS = $(wildcard ${REF_PATH}/AN_AC.*.phased.vcf.gz)
PANEL_CHRS = $(patsubst ${REF_PATH}/AN_AC.%.phased.vcf.gz,%,${TAGGED_VCFS})
SPLIT_STAMPS = $(patsubst %,${REF_PATH}/split/done.%.stamp,${PANEL_CHRS})

check2:
	@echo "TAGGED_VCFS: ${TAGGED_VCFS}"
	@echo "PANEL_CHRS: ${PANEL_CHRS}"
	@echo "SPLIT_STAMPS: ${SPLIT_STAMPS}"

step2_split_and_chunking_panel: ${REF_PATH}/split/bins.txt

${REF_PATH}/split/done.%.stamp: ${REF_PATH}/AN_AC.%.phased.vcf.gz
	$(call activate,${GLIMPSE2_ENV})
	cd ${REF_PATH}
	mkdir -p split
	GLIMPSE2_chunk --input AN_AC.$*.phased.vcf.gz --region $* --window-mb 5.0 --buffer-mb 1.0 --output chunks.$*.txt --sequential --threads 12
	while IFS="" read -r LINE || [ -n "$$LINE" ];
	do
	printf -v ID "%02d" $$(echo $$LINE | cut -d" " -f1)
	    IRG=$$(echo $$LINE | cut -d" " -f3)
	    ORG=$$(echo $$LINE | cut -d" " -f4)
	    GLIMPSE2_split_reference --reference AN_AC.$*.phased.vcf.gz --input-region $${IRG} --output-region $${ORG} --output ./split/split
	done < chunks.$*.txt
	touch ${CURDIR}/$@

${REF_PATH}/split/bins.txt: ${SPLIT_STAMPS}
	@if [ -z "${SPLIT_STAMPS}" ]; then echo "No ${REF_PATH}/AN_AC.*.phased.vcf.gz files, so no chromosome jobs were started."; exit 1; fi
	mkdir -p ${REF_PATH}/split
	cd ${REF_PATH}/split/
	for bin in `ls -1v split_*.bin` ; do basename $$bin .bin ; done | sed 's/^split\_//g' > bins.txt


# step3 Perform genotype imputation per bin using GLIMPSE2
# step3 in parallel: one GLIMPSE2_phase job per bin.
# Each job uses 12 threads, so -j should be about (cores / 12).
# make -f phased_vcf.mk -j 4 step3_imputation_per_bin
#
SPLIT_BINS = $(patsubst ${REF_PATH}/split/split_%.bin,%,$(wildcard ${REF_PATH}/split/split_*.bin))
BIN_BCFS = $(patsubst %,${OUT}/%.bcf,${SPLIT_BINS})
BAMLIST = ${OUT}/bamlist.txt

check3:
	#@echo "SPLIT_BINS: ${SPLIT_BINS}"
	#@echo "BIN_BCFS: ${BIN_BCFS}"
	#@echo "BAMLIST: ${BAMLIST}"

step3_imputation_per_bin: ${BIN_BCFS}

${BAMLIST}: $(wildcard ${BAMS}/*.bam)
	mkdir -p $(dir $@)
	ls ${BAMS}/*.bam > $@

${OUT}/%.bcf: ${REF_PATH}/split/split_%.bin ${BAMLIST}
	$(call activate,${GLIMPSE2_ENV})
	mkdir -p $(dir $@)
	GLIMPSE2_phase \
		--bam-list ${BAMLIST} --reference $< \
		--output $@ --threads 12

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


#
# Tests
#

#
# step2 Chunking and splitting the phased reference panel for GLIMPSE2 imputation
#
step2_split_and_chunking_panel_org:
	$(call activate,${GLIMPSE2_ENV})
	cd ${REF_PATH}
	#ls AN_AC*.vcf.gz | sed -n 's/^AN_AC\.\(.*\)\.phased\.vcf\.gz$$/\1/p' | grep -v '^AN_AC\.' > chrlist.txt
	mkdir -p split
	cat chrlist.txt | while read chr
	do
	GLIMPSE2_chunk --input AN_AC.$${chr}.phased.vcf.gz --region $${chr} --window-mb 5.0 --buffer-mb 1.0 --output chunks.$${chr}.txt --sequential --threads 12
	while IFS="" read -r LINE || [ -n "$$LINE" ];
	do
	printf -v ID "%02d" $$(echo $$LINE | cut -d" " -f1)
	    IRG=$$(echo $$LINE | cut -d" " -f3)
	    ORG=$$(echo $$LINE | cut -d" " -f4)
	    GLIMPSE2_split_reference --reference AN_AC.$${chr}.phased.vcf.gz --input-region $${IRG} --output-region $${ORG} --output ./split/split
	done < chunks.$$chr.txt
	done
	cd split
	for bin in `ls -1v split_*.bin` ; do basename $$bin .bin ; done | sed 's/^split\_//g' > bins.txt



#
# step3 Perform genotype imputation per bin using GLIMPSE2
#
step3_imputation_per_bin_org:
	$(call activate,${GLIMPSE2_ENV})
	mkdir -p ${OUT}
	ls ${BAMS}/*.bam > bamlist
	GLIMPSE2_phase \
		--bam-list ./bamlist --reference ${REF_PATH}/split/split_${BIN}.bin \
	        --output ${OUT}/${BIN}.bcf --threads 12