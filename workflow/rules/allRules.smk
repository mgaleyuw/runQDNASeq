import pandas as pd
import subprocess as sp
import glob

THREADS=config["threads"]
OUTPUTDIR=config["output_dir"]

samples = pd.read_csv(config["metadata"]).set_index("SampleID")

SAMPLE_WORKPATH="".join([OUTPUTDIR,"/","{SAMPLEID}-{ADDNAME}.bins{BIN}"])
LOG_REGEX="logs/{SAMPLEID}-{ADDNAME}.bins{BIN}."

def get_bam(wildcards):
    bamname=samples.loc[wildcards.SAMPLEID,"PhasedBam"]
    return { "bam":bamname, "bai":f"{bamname}.bai"}

def get_targets(wildcards):
    f = open(config["targetfile"], "r")
    targets = f.read().split("\n")
    f.close()
    final_targets=[]
    for target in targets:
        addName=samples.loc[target,"AdditionalNames"]
        #extensions=["called_cnv.pdf", "called_cnv.detail_plot.png", "called_cnv.annotated.vcf"]
        extensions=["subsampled.phased.bam"]
        final_targets+=[f"{OUTPUTDIR}/{target}-{addName}.bins{str(config['cnv_binsize'])}.{x}" for x in extensions]
    return final_targets

rule run_qdnaseq:
    input:
        aligned_bam=f"{SAMPLE_WORKPATH}.subsampled.phased.bam",
        aligned_bam_index = f"{SAMPLE_WORKPATH}.subsampled.phased.bam.bai"
    output:
        qdnaseq_seg=temp("".join([SAMPLE_WORKPATH, ".called_cnv.seg"])),
        qdnaseq_bins=temp("".join([SAMPLE_WORKPATH, ".cnv.bins.txt"])),
        qdnaseq_vcf=temp("".join([SAMPLE_WORKPATH, ".called_cnv.vcf"])),
        qdnaseq_pdf="".join([SAMPLE_WORKPATH, ".called_cnv.pdf"])
    threads: THREADS
    conda:
         config["conda_qdnaseq"]
    log:
        o = "".join(["logs/",LOG_REGEX,"run_qdnaseq","-stdout.log"]),
        e = "".join(["logs/",LOG_REGEX,"run_qdnaseq","-stderr.log"])
    params:
        output_trunk=SAMPLE_WORKPATH,
        bins=config["cnv_binsize"]
    shell:
        """
        Rscript workflow/scripts/qdnaseq_sop_explicitPrint.R -t {threads} -b {params.bins} {input.aligned_bam} {params.output_trunk} > {log.o} 2> {log.e}
        """

rule plot_qdnaseq:
    input:
        qdnaseq_seg="".join([SAMPLE_WORKPATH, ".called_cnv.seg"]),
        qdnaseq_bins="".join([SAMPLE_WORKPATH, ".cnv.bins.txt"])
    output:
        qdnaseq_plot="".join([SAMPLE_WORKPATH, ".called_cnv.detail_plot.png"])
    conda:
        config["conda_qdnaseq"]
    log:
        o = "".join(["logs/",LOG_REGEX,"plot_qdnaseq","-stdout.log"]),
        e = "".join(["logs/",LOG_REGEX,"plot_qdnaseq","-stderr.log"])
    shell:
        """
        Rscript workflow/scripts/qdnaseq_plot.R {input.qdnaseq_seg} {input.qdnaseq_bins} {output.qdnaseq_plot}
        """

rule annotate_cnvs:
    input:
        qdnaseq_seg="".join([SAMPLE_WORKPATH, ".called_cnv.seg"]),
        qdnaseq_vcf="".join([SAMPLE_WORKPATH, ".called_cnv.vcf"])
    output:
        qdnaseq_vcf="".join([SAMPLE_WORKPATH, ".called_cnv.annotated.vcf"])
    conda:
        config["conda_bedtools"]
    log:
        o = "".join(["logs/",LOG_REGEX,"annotate_qdnaseq","-stdout.log"]),
        e = "".join(["logs/",LOG_REGEX,"annotate_qdnaseq","-stderr.log"])
    params:
        genedf=config["geneAnnotationBed"],
        filetrunk=SAMPLE_WORKPATH
    shell:
        """
        INPUTFILE={input.qdnaseq_seg}
        TRUNK={params.filetrunk}
        VCF={input.qdnaseq_vcf}

        INLINES=$( wc -l $INPUTFILE | cut -d ' ' -f1)
        if [[ $INLINES -lt 2 ]]
        then
            grep ^# $VCF > {output.qdnaseq_vcf}
        else
            paste <( tail -n+2 $INPUTFILE | awk '{{print "chr"$2}}' ) <(tail -n+2 $INPUTFILE | cut -f3,4 ) > $TRUNK.intervals.bed

            bedtools intersect -b {params.genedf} -a $TRUNK.intervals.bed -wa -wb -loj > $TRUNK.gene.intersections.2.bed

            grep ^## $VCF | head -n-1 > {output.qdnaseq_vcf}
            echo "##INFO=<ID=GENECOUNT,Number=1,Type=Integer,Description=\"Number of overlapping genes in call\">" >> {output.qdnaseq_vcf}
            echo "##INFO=<ID=GENENAMES,Number=1,Type=String,Description=\"Overlapping genes in call\">" >> {output.qdnaseq_vcf}
            grep ^## $VCF | tail -n1 >> {output.qdnaseq_vcf}
            grep ^#CHROM $VCF >> {output.qdnaseq_vcf}

            paste <(paste <(grep -v ^# $VCF | cut -f1-7) <(paste <(grep -v ^# $VCF | cut -f8) <(paste <(awk 'NR==1{{id=$1":"$2;if($7=="."){{genes=0}}else{{genes=1}}}}\
            NR>1{{newid=$1":"$2;if(id==newid){{genes+=1}}else{{print genes;id=newid;if($7=="."){{genes=0}}else{{genes=1}}}}}}END{{print genes}}' $TRUNK.gene.intersections.2.bed)\
            <(awk 'NR==1{{id=$1":"$2;genes=$7}}NR>1{{newid=$1":"$2;if(id==newid){{genes=genes"-"$7}}else{{print genes;id=newid;genes=$7}}}}END{{print genes}}' $TRUNK.gene.intersections.2.bed) \
            | awk '{{print "GENECOUNT="$1";GENENAMES="$2}}') | tr '\t' ';')) <(grep -v ^# $VCF | cut -f9,10) >> {output.qdnaseq_vcf}

            rm -rf $TRUNK.gene.intersections.2.bed
            rm -rf $TRUNK.intervals.bed
        fi
        """

rule subsample_bam:
    input: unpack(get_bam)
    output: 
        bam=f"{SAMPLE_WORKPATH}.subsampled.phased.bam",
        bai=f"{SAMPLE_WORKPATH}.subsampled.phased.bam.bai"
    threads: THREADS
    params:
        f=0.10
    conda: config["conda_samtools"]
    shell:
        """
        samtools view -@ {THREADS} --subsample {params.f} -bo {output.bam} {input.bam}  
        samtools index -@ {THREADS} {output.bam}
        """
