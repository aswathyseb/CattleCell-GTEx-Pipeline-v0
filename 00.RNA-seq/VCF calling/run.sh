
# Step1
time make -f phased_vcf.mk step1_preprocessing_panel -j 12

#real    35m6.002s
#user    292m48.770s
#sys     0m45.261s


# Step2
time make -f phased_vcf.mk step2_split_and_chunking_panel -j 12
# real	17m17.536s
# user	182m39.765s
# sys	2m39.969s


# Step3
time make -f phased_vcf.mk step3_imputation_per_bin -j 4




## Step2 org
time make -f phased_vcf.mk step2_split_and_chunking_panel
real    159m4.714s
user    167m34.313s
sys     2m16.348s
