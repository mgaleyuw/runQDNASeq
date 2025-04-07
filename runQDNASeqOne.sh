#!/bin/bash

# debugging 2024-04-07

THREADS=1
SERVER="mcclintock"
RUNCONFIG=0
CONFIGFILE="config/config.yaml"

while getopts "t:s:e:o:b:C:w:i:n:B:" option; do
  case $option in
    t) THREADS="$OPTARG" ;;
    s) SERVER="$OPTARG" ;;
    e) EMAIL="$OPTARG" ;;
    o) OUTPUTDIR="$OPTARG" ;;
    b) BINSIZE="$OPTARG" ;;
    C) CORES="$OPTARG" ;;
    w) WILDCARDPATTERN="$OPTARG" ;;
    i) SAMPLEID="$OPTARG" ;;
    n) NAME="$OPTARG" ;;
    B) BAMFILE="$OPTARG" ;;
  esac
done

if [ -z ${CORES+x}]
then
    CORES=$THREADS
fi

#make copy of config input file to edit

CONFIGWORKING="config/config_working.yaml"
cp $CONFIGFILE $CONFIGWORKING


# make metadata one off

if [ -z ${SAMPLEID+x}]
then
    echo "sample identifier must be supplied, exiting"
    exit 1
fi
if [ -z ${BAMFILE+x}]
then
    echo "bam file input must be supplied, exiting"
    exit 1
fi
if [ -z ${NAME+x}]
then
    echo "no additional name identifier supplied, using 'qdnaseq'"
    NAME="qdnaseq"
fi

echo "SampleID,AdditionalNames,PhasedBam" > config/metadata_oneoff.csv
echo "$SAMPLEID,$NAME,$BAMFILE" >> config/metadata_oneoff.csv

echo "$SAMPLEID" > targets.txt

sed -i "s?metadata: .*?metadata: config/metadata_oneoff.csv?g" -e $CONFIGWORKING

#edit config file
if [ -z ${THREADS+x} ]
then
    sed -i "s/threads: .*/threads: $THREADS/g" -e $CONFIGWORKING
fi
if [ -z ${SERVER+x} ]
then
    sed -i "s/server: .*/server: $SERVER/g" -e $CONFIGWORKING
fi
if [ -z ${EMAIL+x} ]
then
    sed -i "s/email: .*/email: $EMAIL/g" -e $CONFIGWORKING
fi
if [ -z ${OUTPUTDIR+x} ]
then
    sed -i "s?output_dir: .*?output_dir: $OUTPUTDIR?g" -e $CONFIGWORKING
fi
if [ -z ${BINSIZE+x} ]
then
    sed -i "s/cnv_binsize: .*/cnv_binsize: $BINSIZE/g" -e $CONFIGWORKING
fi

#edit snakefile

if [ -z ${WILDCARDPATTERN+x} ]
then
    # this line will almost certainly not work
    sed -i 's?sampleidpattern=.*?sampleidpattern=r\'"$WILDCARDPATTERN"'?g' -e Snakefile
fi

echo -e "\nrunning with the following config options: \n"
cat $CONFIGWORKING
echo ""

sed -i "s?configfile: .*?configfile: $CONFIGWORKING?g" -e Snakefile

echo "snakemake --use-conda --cores $CORES"
#snakemake --use-conda --cores $CORES


