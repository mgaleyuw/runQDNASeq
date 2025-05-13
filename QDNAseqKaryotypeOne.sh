#!/bin/bash

# debugging 2024-04-08

help(){
    echo """
    QDNAseqKaryotypeOne.sh

    This is a wrapper to run the qdnaseq for karyotype snakemake for just one sample.

    To run the snake for multiple samples, use QDNAseqKaryotypeMany.sh instead.

    Usage: bash QDNAseqKaryotypeOne.sh -i SampleIdentifier -B a/path/to/input.bam

    If your sample identifier does not follow the pattern M\d{4}, specify your pattern using the flag '-w'
    By default this script names output files 'SampleID-qdnaseq-bins{binnumber}.{extension}'.
    You can change the 'qdnaseq' part of the name using flag '-n'

    Other flags:
    -t: number of threads to use for each sample (default 1)
    -s: server (default: mcclintock. accepts franklin, case-sensitive)
    -e: email notification for results (PLEASE CHANGE THIS WHEN RUNNING)
    -o: output directory (default: results)
    -b: bin size, in kb (default: 500)
    -C: cores to use for run (default equal to threads)
    -w: wildcard pattern. This must be supplied in single quotes, e.g. 'M\\d{4}' not M\\d{4}
    -i: sample identifier (required)
    -n: name to include in output files
    -B: bam file path (required)
    -S: subsampling level (default: 0.10). To include all reads, in the case of small datasets, set -S to 1.0
    -f: run without confirmation. By default this wrapper will ask you to confirm settings before running.
    -a: any additional arguments to pass to snakemake (in single quotes)
    -h: this helpful help

    """
}

THREADS=1
SERVER="mcclintock"
RUNCONFIG=0
CONFIGFILE="config/config.yaml"
FORCE=0

while getopts "t:s:e:o:b:C:w:i:n:B:hfa:S:" option; do
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
    f) FORCE=1 ;;
    a) ADDSTRING="$OPTARG" ;;
    S) SUBSAMPLING="$OPTARG" ;;
    h) help
       exit 0 ;;
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

echo "SampleID,AdditionalNames,PhasedBam" > config/metadata_oneoff.csv
echo "$SAMPLEID,$NAME,$BAMFILE" >> config/metadata_oneoff.csv

#make target file

echo -n "$SAMPLEID" > config/oneoff_targets.txt


#make copy of config input file to edit

CONFIGWORKING="config/config_working.yaml"
cp $CONFIGFILE $CONFIGWORKING


#edit config file

sed -i -e "s!metadata: .*!metadata: config/metadata_oneoff.csv!g" $CONFIGWORKING
sed -i -e "s!targetfile: .*!targetfile: config/oneoff_targets.txt!g" $CONFIGWORKING

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
if [ -z ${SUBSAMPLING+x} ]
then
    echo "no subsampling specified, using default"
else
    sed -i -e "s/subsampling: .*/subsampling: $SUBSAMPLING/g" $CONFIGWORKING
fi


if [ -z ${WILDCARDPATTERN+x} ]
then
    echo "no wildcard pattern specified"
else
    echo "wildcard pattern specified: $WILDCARDPATTERN"
    echo ""
    export WILDCARDSTRING='sampleidpattern: "'"$WILDCARDPATTERN"'"'
    perl -p -i -e 's/sampleidpattern:.*/$ENV{WILDCARDSTRING}/g' "$CONFIGWORKING"
fi

echo -e "\nrunning with the following config options: \n"
cat $CONFIGWORKING
echo -e "\n"

#edit snakefile

export CONFIGSTRING='configfile: "'"$CONFIGWORKING"'"'
perl -p -i -e 's/configfile: .*/$ENV{CONFIGSTRING}/g' workflow/Snakefile
#sed -i -e "s!configfile: .*!configfile: $CONFIGWORKING!g" workflow/Snakefile

if [ $FORCE -eq 0 ]
then
    echo "command to run: "
    echo "snakemake --use-conda --conda-frontend conda --cores $CORES $ADDSTRING"
    echo -e "\n"
    read -p "Proceed? (Y/N)"
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        echo "running"
        snakemake --use-conda --conda-frontend conda --cores $CORES $ADDSTRING
    else
        echo "QDNAseq Karyotype did not run"
    fi
    exit 0
else
    echo "running without confirmation"
    snakemake --use-conda --conda-frontend conda --cores $CORES $ADDSTRING
fi

