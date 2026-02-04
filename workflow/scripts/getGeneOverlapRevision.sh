#!/bin/bash

# requires tabix, so samtools or bcftools in path. bedtools no longer required

GENES=/n/dat/hg38/resorted.hg38.genes.mergedintervals.tsv.gz
OUTPUTDIR=$(pwd)
VCFONLY=0
chr="chr"
endfield=4;
temp=$(mktemp -u)

while getopts "i:o:vs" option; do
  case $option in
    i) INPUTFILE="$OPTARG";;
    o) OUTPUTDIR="$OPTARG";;
    s) chr="";endfield=2;;
  esac
done


FILE=${INPUTFILE##*/}

ENDING=${FILE##*.}
if [ $ENDING == "gz" ]
then
    TRUNK="$OUTPUTDIR/${FILE%*.vcf.gz}"
    GREP=zgrep
else
    TRUNK="$OUTPUTDIR/${FILE%*.vcf}"
    GREP=grep
fi

VCF=$INPUTFILE


regions=( $(paste <( $GREP -v "^#" $VCF | awk -v chr=$chr '{print chr$1,$2}' | tr ' ' '\t' ) \
<( $GREP -v "^#" $VCF | cut -f8 | tr ';' '\t' | tr '=' '\t' | cut -f $endfield) | awk '{print $1":"$2"-"$3}') )
geneinfo=()

for region in ${regions[@]}
do
    tabix $GENES $region > $temp.$region.bed
    genelist=( $(cut -f1 $temp.$region.bed | grep -v "None") )
    if [ ${#genelist[@]} -eq 0 ]
    then
        genestring="."
    else
        genestring=$( echo ${genelist[@]} | tr ' ' ',')
    fi
    geneinfo+=( "GENECOUNT=${#genelist[@]};GENENAMES=$genestring")
    rm $temp.$region.bed
done


$GREP ^## $VCF | head -n-1 > $TRUNK.annotated.vcf
echo "##INFO=<ID=GENECOUNT,Number=1,Type=Integer,Description=\"Number of overlapping genes in call\">" >> $TRUNK.annotated.vcf
echo "##INFO=<ID=GENENAMES,Number=1,Type=String,Description=\"Overlapping genes in call\">" >> $TRUNK.annotated.vcf
$GREP ^## $VCF | tail -n1 >> $TRUNK.annotated.vcf
$GREP ^#CHROM $VCF >> $TRUNK.annotated.vcf

paste <($GREP -v ^# $VCF | cut -f1-7) <(paste <($GREP -v ^# $VCF | cut -f8) <(echo ${geneinfo[@]} | tr ' ' '\n') | tr '\t' ';') <($GREP -v ^# $VCF | cut -f9,10) >> $TRUNK.annotated.vcf

