#!/usr/bin/env Rscript

args = commandArgs(trailingOnly=TRUE)
segfile=args[1]
binsfile=args[2]
outputname=args[3]
chr=args[4]

bindf <- read.table(file=binsfile, header=TRUE, sep="\t")
colnames(bindf) <- c("feature", "chromosome", "start", "end", "SAMPLE")
segdf <- read.table(file=segfile, header=TRUE, sep="\t")

library(dplyr)
library(ggplot2)

theme_set(theme_classic(base_size=9))

g <- ggplot() + geom_rect(data=segdf %>% filter(CHROMOSOME==chr), aes(xmin=START, xmax=STOP, ymin=-2, ymax=2),
    fill="deeppink1") + geom_point(data=bindf %>% filter(chromosome==chr), aes(x=start, y=SAMPLE), shape='.') + 
    ylab("Fold Change") + scale_x_continuous(labels=scales::label_bytes(), name="Position") + ggtitle(paste("Chr", chr)) +
    coord_cartesian(ylim=c(-3,3)) + theme(plot.title=element_text(hjust=0.5))

ggsave(outputname, plot=g, dpi=300, width=8.5, height=10, units="in")