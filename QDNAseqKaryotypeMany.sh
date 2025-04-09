#!/bin/bash


# debugging 2024-04-08

help(){
    echo """
    QDNAseqKaryotypeMany.sh

    This is a wrapper to run the qdnaseq for karyotype snakemake for more than one sample without directly editing the metadata, targets, or Snakefile.

    To run the snake for only one sample specifying inputs at the command line, use QDNAseqKaryotypeMany.sh instead.

    Usage: bash runQDNASeqMany.sh -m a/path/to/metadata/file -T a/path/to/target/file

    If your sample identifier does not follow the pattern M\d{4}, specify your pattern using the flag '-w'
    

    Other flags:
    -c: run with existing config file rather than command line arguments
    -f: path to a config file if not 'config/config.yaml'
    -t: number of threads to use for each sample (default 1)
    -s: server (default: mcclintock. accepts franklin, case-sensitive)
    -e: email notification for results (PLEASE CHANGE THIS WHEN RUNNING)
    -o: output directory (default: results)
    -b: bin size, in kb (default: 500)
    -C: cores to use for run (default equal to threads)
    -w: wildcard pattern. This must be supplied in single quotes, e.g. 'M\\d{4}' not M\\d{4}
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

while getopts "t:s:cm:T:e:o:b:C:f:w:a:S:h" option; do
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

#make copy of config input file to edit

CONFIGWORKING="config/config_working.yaml"
cp $CONFIGFILE $CONFIGWORKING

# edit config file


if [ $RUNCONFIG -eq 1 ]
then
    echo "flag -c included: ignoring command line options except -C (cores) and -f (config file location) and running from config.yaml"
    echo ""
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
else
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

fi


