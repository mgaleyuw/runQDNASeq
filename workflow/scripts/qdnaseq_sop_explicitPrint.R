#!/usr/bin/env Rscript --vanilla

suppressWarnings(suppressPackageStartupMessages(library(optparse)))
suppressWarnings(suppressPackageStartupMessages(library(plyr)))
suppressWarnings(suppressPackageStartupMessages(library(dplyr)))

option_list <- list(make_option(c("-t", "--threads"), action="store", help="Threads to use", default=1),
                    make_option(c("-s", "--seed"), action="store", help="random seed", default=1234),
                    make_option(c("-b", "--binSize"), action="store", help="bin size: options are 1,5,10,15,30,50,100,500 or 1000kbp. Default=10", default=10)
                    )

parser <- OptionParser(usage="%prog [options] input output", option_list=option_list, description="\nRun QDNASeq with hg38 bins.\n
Example: ./qdnaseq_sop.R -b 15 -t 30 m12345.phased.bam m12345.qdnaseqoutput   -->     outputs m12345.qdnaseqoutput.called_cnv.seg, m12345.qdnaseqoutput.caled_cnv.vcf,\n m12345.qdnaseqoutput.called_cnv.pdf, and m12345.qdnaseqoutput.cnv.bins.txt with 10kb bins using 30 threads")

arguments <- parse_args(parser, positional_arguments=2)
opt <- arguments$options

bamfile <- arguments$args[1]
outputname <- arguments$args[2]
threads <- opt$threads
binSize <- opt$binSize

set.seed(opt$seed)

suppressWarnings(suppressPackageStartupMessages(library(QDNAseq)))
suppressWarnings(suppressPackageStartupMessages(library(QDNAseq.hg38)))

future::plan("multisession", workers=threads)

bins <- getBinAnnotations(binSize=binSize, genome="hg38")
readCounts <- binReadCounts(bins, bamfiles=bamfile)
readCountsFiltered <- applyFilters(readCounts, residual=TRUE, blacklist=TRUE, mappability=60)

readCountsFiltered <- estimateCorrection(readCountsFiltered)
readCountsFiltered <- applyFilters(readCountsFiltered, chromosomes="Y", residual=TRUE, blacklist=TRUE, mappability=60)

copyNumbers <- correctBins(readCountsFiltered)
copyNumbersNormalized <- normalizeBins(copyNumbers)
copyNumbersSmooth <- smoothOutlierBins(copyNumbersNormalized)

exportBins(copyNumbersSmooth, file=paste(outputname, ".cnv.bins.txt", sep=""))

copyNumbersSegmented <- segmentBins(copyNumbersSmooth, transformFun="sqrt")
copyNumbersSegmented <- normalizeSegmentedBins(copyNumbersSegmented)

copyNumbersCalled <- callBins(copyNumbersSegmented, method="cutoff")

pdf(file=paste(outputname, ".called_cnv.pdf", sep=""))
par(mar=c(4.1, 4.4, 4.1, 1.0), xaxs="i", yaxs="i")
plot(copyNumbersCalled)
dev.off()

# the following replaces exportBins to save output, which is broken in qdnaseq v1.40.0 when only one CNV is found.
# modified to use dplyr/plyr 2025-05-13
calls <- Biobase::assayDataElement(copyNumbersCalled, "calls")
segments <- log2(Biobase::assayDataElement(copyNumbersCalled, "segmented"))
fd <- Biobase::fData(copyNumbersCalled)
pd <- Biobase::pData(copyNumbersCalled)

vcfHeader <- cbind(c(
                         '##fileformat=VCFv4.2',
                         paste('##source=QDNAseq-', packageVersion("QDNAseq"), sep=""),
                         '##REF=<ID=DIP,Description="CNV call">',
                         '##ALT=<ID=DEL,Description="Deletion">',
                         '##ALT=<ID=DUP,Description="Duplication">',
                         '##FILTER=<ID=LOWQ,Description="Filtered due to call in low quality region">',
                         '##INFO=<ID=SVTYPE,Number=1,Type=String,Description="Type of variant: DEL,DUP,INS">',
                         '##INFO=<ID=END,Number=1,Type=Integer,Description="End position of variant">',
                         '##INFO=<ID=SVLEN,Number=1,Type=Integer,Description="Length of variant">',
                         '##INFO=<ID=BINS,Number=1,Type=Integer,Description="Number of bins in call">',
                         '##INFO=<ID=SCORE,Number=1,Type=Integer,Description="Score of calling algorithm">',
                         '##INFO=<ID=LOG2CNT,Number=1,Type=Float,Description="Log 2 count">', 
                         '##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">'
                         ))

i=1
ddf <- data.frame(cbind(fd[,1:3], calls[,i], segments[,i]))
dfsel <- ddf %>% filter( ! is.na(calls[,i]))
colnames(dfsel) <- c("chromosome", "start", "end", "calls", "segments")

dfr <- dfsel %>% mutate(record=paste(chromosome,calls, sep=":")) %>% group_by(chromosome, record) %>%
 summarize(pos=min(start), end=max(end), score=max(calls),
  segVal=max(round(segments, digits=2)), bins=n()) %>% mutate(svlen=end-pos+1,
   svtype=ifelse(score <= -1, "DEL", "DUP"), gt=ifelse(score>=-1,"0/1","1/1") ) %>%
    filter(score !=0) %>% mutate(id=".", ref="<DIP>", alt=paste("<", svtype,">", sep=""), 
    qual=1000, filter="PASS", info=paste("SVTYPE=", svtype, ";END=", end, ";SVLEN=", svlen, 
    ";BINS=", bins, ";SCORE=", score, ";LOG2CNT=", segVal, sep=""), format="GT", sample=gt)

vcf <- dfr %>% select(chromosome, pos, id, ref, alt, qual, filter, info, format, sample)
vcf <- data.frame(vcf)
colnames(vcf) <- c("#CHROM", "POS", "ID", "REF", "ALT", "QUAL", "FILTER", "INFO", "FORMAT", pd$name[i])
write.table(vcfHeader, file=paste(outputname, ".called_cnv.vcf", sep=""), quote=FALSE, sep="\t", col.names=FALSE, row.names=FALSE)
suppressWarnings(write.table(vcf, file=paste(outputname, ".called_cnv.vcf", sep=""), quote=FALSE, sep="\t", append=TRUE, col.names=TRUE, row.names=FALSE))

dfr <- dfr %>% mutate(samplename=pd$name[i])
tsv <- dfr %>% select(samplename, chromosome, pos, end, bins, segVal)        
tsv <- data.frame(tsv)
colnames(tsv) <- c("SAMPLE_NAME", "CHROMOSOME", "START", "STOP", "DATAPOINTS", "LOG2_RATIO_MEAN")
write.table(tsv, file=paste(outputname, ".called_cnv.seg", sep=""), quote=FALSE, sep="\t", col.names=TRUE, row.names=FALSE)


#exportBins(copyNumbersCalled, format="seg", file=paste(outputname, ".called_cnv.seg", sep=""))
#exportBins(copyNumbersCalled, format="vcf", file=paste(outputname, ".called_cnv.vcf", sep=""))


