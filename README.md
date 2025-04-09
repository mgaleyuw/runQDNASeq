# QDNAseq optimized for karyotyping


This is a snakemake workflow that runs qdnaseq, annotates genes in the VCF and plots CNVs.


The workflow is optimized for karyotyping but can be used with other settings.


Use the two provided wrappers to run QDNAseq efficiently from the command line. 

`QDNAseqKaryotypeOne.sh` should be used when karyotyping only one sample.
`QDNAseqKaryotypeMany.sh` should be used when karyotyping more than one sample using the same settings. This is a more efficient use of multiprocessing. See the files in `config` for an example of how to set up the metadata and target files.

==When karyotyping an average depth ONT dataset (~30x coverage), subsampling should be used and the default of 10% should work well. If karyotyping a smaller dataset, with < 10x coverage, **turn subsampling off by setting the flag `-S 1.0`**.==


## Usage

Run all scripts within a snakemake environment (`conda activate snakemake-8.16.0`)

### QDNAseqKaryotypeOne.sh

    This is a wrapper to run the qdnaseq for karyotype snakemake for just one sample.

    To run the snake for multiple samples, use QDNAseqKaryotypeMany.sh instead.

    Usage: bash runQDNASeqOne.sh -i SampleIdentifier -B a/path/to/input.bam

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

### QDNAseqKaryotypeMany.sh

    This is a wrapper to run the qdnaseq for karyotype snakemake for more than one sample without directly editing the metadata, targets, or Snakefile.

    To run the snake for only one sample specifying inputs at the command line, use QDNAseqKaryotypeMany.sh instead.

    Usage: bash runQDNASeqMany.sh -m a/path/to/metadata/file -T a/path/to/target/file

    If your sample identifier does not follow the pattern M\d{4}, specify your pattern using the flag '-w'
    

    All flags:
    -c: run with existing config file rather than command line arguments, can be combined with '-F' below
    -F: path to a config file if not 'config/config.yaml'
    -T: path to a target file (uses config/targets.txt by default)
    -m: path to a metadata file (uses config/metadata.csv by default)
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

