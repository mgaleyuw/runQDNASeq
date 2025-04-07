#!/usr/bin/env Rscript

args = commandArgs(trailingOnly=TRUE)
segfile=args[1]
binsfile=args[2]
outputname=args[3]

bindf <- read.table(file=binsfile, header=TRUE, sep="\t")
colnames(bindf) <- c("feature", "chromosome", "start", "end", "SAMPLE")
segdf <- read.table(file=segfile, header=TRUE, sep="\t")

library(dplyr)
library(ggplot2)

if(nrow(segdf)==0){
    g <- ggplot() + geom_text(aes(x=1, y=1, label="No CNVs Detected"))
    ggsave(outputname, dpi=300, width=8.5, height=10, units="in")
} else {
    segdf$weight <- abs(segdf$LOG2_RATIO_MEAN)

    theme_set(theme_classic(base_size=9))

    chromosomes <- seq(1,22)
    chromosomes <- c(chromosomes, "X")

    allplots=list()
    for(chr in chromosomes){
        g <- ggplot() + geom_rect(data=segdf %>% filter(CHROMOSOME==chr), aes(xmin=START, xmax=STOP, ymin=-2, ymax=2, alpha=weight),
        fill="deeppink1") + geom_point(data=bindf %>% filter(chromosome==chr), aes(x=start, y=SAMPLE), shape='.') + 
        ylab("Fold Change") + scale_x_continuous(labels=scales::label_bytes(), name="Position") + ggtitle(paste("Chr", chr)) +
        geom_hline(yintercept=0, linetype="dashed", color="gray") +
        coord_cartesian(ylim=c(-3,3)) + theme(plot.title=element_text(hjust=0.5), legend.position="none") + scale_alpha_continuous(range=c(0.1,1), limits=c(0,1.5))
        allplots=c(allplots, list(g))
    }

    plotlist=list(plots=allplots, num=23)
    do.call(cowplot::plot_grid, c(plotlist$plots))

    ggsave(outputname, dpi=300, width=8.5, height=10, units="in")
}