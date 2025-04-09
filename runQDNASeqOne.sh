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

# make metadata one off

if [ -z ${SAMPLEID+x} ]
then
    echo "sample identifier must be supplied, exiting"
    exit 1
fi
if [ -z ${BAMFILE+x} ]
then
    echo "bam file input must be supplied, exiting"
    exit 1
fi
if [ -z ${NAME+x} ]
then
    echo "no additional name identifier supplied, using 'qdnaseq'"
    NAME="qdnaseq"
fi

#make copy of config input file to edit

CONFIGWORKING="config/config_working.yaml"
cp $CONFIGFILE $CONFIGWORKING

echo "SampleID,AdditionalNames,PhasedBam" > config/metadata_oneoff.csv
echo "$SAMPLEID,$NAME,$BAMFILE" >> config/metadata_oneoff.csv

echo "$SAMPLEID" > config/oneoff_targets.txt

sed -i -e "s!metadata: .*!metadata: config/metadata_oneoff.csv!g" $CONFIGWORKING
sed -i -e "s!targetfile: .*!targetfile: config/oneoff_targets.txt!g" $CONFIGWORKING

#edit config file
if [ -z ${THREADS+x} ]
then
    echo "no threads specified, using default ($THREADS)"
    sed -i -e "s/threads: .*/threads: $THREADS/g" $CONFIGWORKING
else
    sed -i -e "s/threads: .*/threads: $THREADS/g" $CONFIGWORKING
fi
if [ -z ${SERVER+x} ]
then
    echo "no server specified, using default ($SERVER)"
    sed -i -e "s/server: .*/server: $SERVER/g" $CONFIGWORKING
else
    sed -i -e "s/server: .*/server: $SERVER/g" $CONFIGWORKING
fi
if [ -z ${EMAIL+x} ]
then
    echo "no email specified, using default"
else    
    sed -i -e "s/email: .*/email: $EMAIL/g" $CONFIGWORKING
fi
if [ -z ${OUTPUTDIR+x} ]
then
    echo "no output dir specified, using outputin current directory"
else
    sed -i -e "s?output_dir: .*?output_dir: $OUTPUTDIR?g" $CONFIGWORKING
fi
if [ -z ${BINSIZE+x} ]
then
    echo "no binsize specified, using default"
else
    sed -i -e "s/cnv_binsize: .*/cnv_binsize: $BINSIZE/g" $CONFIGWORKING
fi

if [ -z ${WILDCARDPATTERN+x} ]
then
    echo "no wildcard pattern specified"
else
    # this line will almost certainly not work
    echo "wildcard pattern specified: $WILDCARDPATTERN"
    echo 's!sampleidpattern:.*!sampleidpattern:r\'"$WILDCARDPATTERN"'!g'
    export WILDCARDSTRING='sampleidpattern: r"'"$WILDCARDPATTERN"'"'
    #export SIMPLE="$WILDCARDPATTERN"
    perl -p -i -e 's/sampleidpattern:.*/$ENV{WILDCARDSTRING}/g' "$CONFIGWORKING"
    #sed -i -e 's!sampleidpattern:.*!sampleidpattern:r\'"$WILDCARDPATTERN"'!g' $CONFIGWORKING
fi

echo -e "\nrunning with the following config options: \n"
cat $CONFIGWORKING
echo -e "\n"

#edit snakefile

sed -i -e "s!configfile: .*!configfile: $CONFIGWORKING!g" workflow/Snakefile

echo "snakemake --use-conda --cores $CORES"
echo -e "\n"
#snakemake --use-conda --cores $CORES


