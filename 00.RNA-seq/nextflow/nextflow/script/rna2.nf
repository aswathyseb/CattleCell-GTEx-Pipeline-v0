params.workpath = "/home/azs13/apps/wansheng-liu/2026_cattle_GTEx/v0_rnaseq"
params.samplelist = "${params.workpath}/samplelist_rnaseq.csv"
params.genomepath = "${params.workpath}/cattle_genome/UCD1.2"
params.starindex = "${params.genomepath}/indexstar/"
params.recalvcf = "${params.workpath}/UCD1.2/vcf/recal.final.vcf.gz"
params.sampleIDs = file("$params.samplelist").readLines().collect { it.split('\t')[0] }.toSet()
params.gtf = "${params.genomepath}/Bos_taurus.ARS-UCD1.2.108.chr.gtf"
params.fa = "${params.genomepath}/Bos_taurus.ARS-UCD1.2.dna.toplevel.fa"
params.outpath = "${params.workpath}/UCD1.2/results"
params.toolpath = "${params.workpath}/tools/"
params.chr = "${params.genomepath}/chr.info"
params.chrinfo = file("${params.genomepath}/chromInfo.txt").readLines().collect { it.split('\t')[0] }.toSet()
params.phaserbed = "${params.genomepath}/Bos_taurus.ARS-UCD1.2.108.phaser.bed"

  include { h5_prepare_1         } from './module/WASP.nf'
  include { h5_prepare_2         } from './module/WASP.nf'
  include { WASP_find            } from './module/WASP.nf'
  include { WASP_remap           } from './module/WASP.nf'
  include { WASP_dedup           } from './module/WASP.nf'
  include { leafcutter           } from './module/mp2.nf'
  include { phaser_snp           } from './module/mp2.nf'
  include { phaser_gene          } from './module/mp2.nf'
workflow{
  h5_prepare_1(params.chrinfo)
  h5_prepare_2(h5_prepare_1.out.vcf.collect())
  WASP_find(params.sampleIDs,h5_prepare_2.out.haplotype,h5_prepare_2.out.index,h5_prepare_2.out.tab)
  WASP_remap(WASP_find.out.fq.join(WASP_find.out.remapbam).join(WASP_find.out.keepbam))
  WASP_dedup(WASP_remap.out.bam)
  leafcutter(WASP_dedup.out.bam)
  phaser_snp(WASP_dedup.out.bam)
  phaser_gene(phaser_snp.out.count)    
}

