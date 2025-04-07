#!/bin/bash

THREADS=1
SERVER="mcclintock"
RUNCONFIG=0
CONFIGFILE="config/config.yaml"

while getopts "t:s:cm:T:e:o:b:C:f:w:" option; do
  case $option in
    t) THREADS="$OPTARG" ;;
    s) SERVER="$OPTARG" ;;
    c) RUNCONFIG=1 ;;
    m) METADATFILE="$OPTARG" ;;
    T) TARGETFILE="$OPTARG" ;;
    e) EMAIL="$OPTARG" ;;
    o) OUTPUTDIR="$OPTARG" ;;
    b) BINSIZE="$OPTARG" ;;
    C) CORES="$OPTARG" ;;
    f) CONFIGFILE="$OPTARG" ;;
    w) WILDCARDPATTERN="$OPTARG" ;;
  esac
done

if [ -z ${CORES+x}]
then
    CORES=$THREADS
fi

#make copy of config input file to edit

CONFIGWORKING="config/config_working.yaml"
cp $CONFIGFILE $CONFIGWORKING

if [ $RUNCONFIG -eq 1 ]
then
    echo "flag -c included: ignoring command line options except -C (cores) and -f (config file location) and running from config.yaml"
    echo ""
    echo -e "config settings: \n"
    cat $CONFIGFILE
    echo ""
    snakemake --use-conda --cores $CORES
else
    if [ -z ${THREADS+x} ]
    then
        sed -i "s/threads: .*/threads: $THREADS/g" -e $CONFIGWORKING
    fi
    if [ -z ${SERVER+x} ]
    then
        sed -i "s/server: .*/server: $SERVER/g" -e $CONFIGWORKING
    fi
    if [ -z ${METADATAFILE+x} ]
    then
        sed -i "s?metadata: .*?metadata: $METADATAFILE?g" -e $CONFIGWORKING
    fi
    if [ -z ${TARGETFILE+x} ]
    then
        sed -i "s?targetfile: .*?targetfile: $TARGETFILE?g" -e $CONFIGWORKING
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
    if [ -z ${WILDCARDPATTERN+x} ]
    then
        # this line will almost certainly not work
        sed -i 's?sampleidpattern=.*?sampleidpattern=r\'"$WILDCARDPATTERN"'?g' -e Snakefile
    fi

    echo -e "\nrunning with the following config options: \n"
    cat $CONFIGWORKING
    echo ""

    sed -i "s?configfile: .*?configfile: $CONFIGWORKING?g" -e Snakefile

    snakemake --use-conda --cores $CORES

fi


