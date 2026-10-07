#
# Download the software and genome files
# 
# Modifications to the original script:
#
# 1. Reference genome, annotationand VCF files:
#    - Currently use Ensembl release 116 (includes Y chromosome)
#    - The original release was 108 (does not include Y chromosome)
# 2. OSCA tool is updated to the latest version (2026)
#    - The original version was 0.46.1
#    - The current version is 1.22


workpath="/home/azs13/apps/wansheng-liu/2026_cattle_GTEx/v0_rnaseq"
toolpath="${workpath}/tools"
genomepath="${workpath}/cattle_genome/"

    mkdir -p $toolpath
    mkdir -p $genomepath
    cd $toolpath

    # The CURRENT Version (2026) of OSCA is 1.22, so we use the link for the current version.
    wget -O osca-1.22-linux-x86_64.zip \
        --user-agent='Mozilla/5.0' \
        https://yanglab.westlake.edu.cn/software/osca/download/osca-1.22-linux-x86_64.zip --no-check-certificate
    unzip -o osca-1.22-linux-x86_64.zip

    # TEdetectionEvaluation

    wget https://github.com/Hoffmann-Lab/TEdetectionEvaluation/archive/refs/heads/main.zip -O TEdetect.zip --no-check-certificate
    wget https://github.com/BioinfoUNIBA/REDItools/archive/refs/heads/master.zip -O REDItools.zip --no-check-certificate
    wget https://github.com/davidaknowles/leafcutter/archive/refs/heads/master.zip -O leaf.zip --no-check-certificate
    wget https://codeload.github.com/3UTR/DaPars2/zip/refs/heads/master -O dapars2.zip --no-check-certificate
    unzip dapars2.zip
    unzip SalmonTools.zip   
    # unzip osca.zip
    unzip TEdetect.zip 
    unzip REDItools.zip 
    unzip leaf.zip
    wget http://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64/gtfToGenePred --no-check-certificate
    wget http://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64/genePredToBed --no-check-certificate
    chmod +x ./gtfToGenePred
    chmod +x ./genePredToBed
    cd $genomepath 
    wget https://ftp.ensembl.org/pub/release-116/fasta/bos_taurus/dna/Bos_taurus.ARS-UCD2.0.dna.toplevel.fa.gz
    wget https://ftp.ensembl.org/pub/release-116/fasta/bos_taurus/cdna/Bos_taurus.ARS-UCD2.0.cdna.all.fa.gz
    wget https://ftp.ensembl.org/pub/release-116/gtf/bos_taurus/Bos_taurus.ARS-UCD2.0.116.chr.gtf.gz
    wget https://ftp.ensembl.org/pub/release-116/variation/vcf/bos_taurus/bos_taurus.vcf.gz
    wget https://ftp.ensembl.org/pub/release-116/variation/vcf/bos_taurus/bos_taurus_structural_variations.vcf.gz
    gunzip *
    
    
    #
    # The original links
    #

    # SalmonTools
    # wget https://github.com/COMBINE-lab/SalmonTools/archive/refs/heads/master.zip -O SalmonTools.zip --no-check-certificate
    
    #
    # OSCA
    # 
    # Original link:wget https://yanglab.westlake.edu.cn/software/osca/download/osca-0.46.1-linux-x86_64.zip -c -O osca.zip --no-check-certificate
    # Software got updated and this version moved into older relases.
    # To get the original version that is used by the pipelineuse the link
    # https://github.com/jianyangqt/osca/releases/download/v0.46.1/osca-0.46.1-linux-x86_64
    # mkdir -p osca-0.46.1-linux-x86_64
    # wget -O osca-0.46.1-linux-x86_64/osca-0.46.1 \
    #    https://github.com/jianyangqt/osca/releases/download/v0.46.1/osca-0.46.1-linux-x86_64
    #chmod +x osca-0.46.1-linux-x86_64/osca-0.46.1
    #
    #
    # Ensembl GTF and fasta files
    #
    # wget https://ftp.ensembl.org/pub/release-108/gtf/bos_taurus/Bos_taurus.ARS-UCD1.2.108.chr.gtf.gz 
    # wget https://ftp.ensembl.org/pub/release-108/fasta/bos_taurus/cdna/Bos_taurus.ARS-UCD1.2.cdna.all.fa.gz
    # wget https://ftp.ensembl.org/pub/release-108/fasta/bos_taurus/dna/Bos_taurus.ARS-UCD1.2.dna.toplevel.fa.gz
    # wget https://ftp.ensembl.org/pub/release-108/variation/vcf/bos_taurus/bos_taurus.vcf.gz
    # wget https://ftp.ensembl.org/pub/release-108/variation/vcf/bos_taurus/bos_taurus_structural_variations.vcf.gz
    # gunzip *