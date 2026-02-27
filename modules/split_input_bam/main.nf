#!/usr/bin/env nextflow

/*
================================================================================
Coriell Institute for Medical Research

Contributors:
Anthony Pompetti <apompetti@coriell.org>
================================================================================
*/

/*
================================================================================
Enable Nextflow DSL2
================================================================================
*/
nextflow.enable.dsl=2

/*
================================================================================
Configurable variables for module
================================================================================
*/
params.outdir = "./nfoutput"

/*
================================================================================
Module declaration
================================================================================
*/

process SPLIT_INPUT_BAM {

    maxForks 4
    cpus 16
    memory 32
    cache 'lenient'

    // Set batch name and sample id to tag
    tag { meta.batch == '' ? "${meta.id}" : "${meta.batch}_${meta.id}" }

    // Do not publish data

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("*.{chunk_*,reset}.bam"), emit: bam

    script:
    def threads = task.cpus > 1 ? task.cpus - 1 : 0
    def movie = bam.simpleName

    """
    cat << EOF > detect_bam_tags.py
    import json, pysam
    def check_bam_file(bam_file_path, n_records):
      output = dict()
      save = pysam.set_verbosity(0)  # suppress [E::idx_find_and_load]
      with pysam.AlignmentFile(bam_file_path, 'rb', check_sq=False) as bam_file:
        pysam.set_verbosity(save)  # restore warnings
        aligned = bool(bam_file.nreferences)
        unique_tags = set()
        for i, record in enumerate(bam_file):
          if i >= n_records: break
          unique_tags.update(tag[0] for tag in record.tags)
      output['kinetics'] = bool(unique_tags & {'fi', 'ri', 'fp', 'rp', 'ip', 'pw'})
      output['base_modification'] = bool(unique_tags & {'MM', 'ML', 'Mm', 'Ml'})
      output['aligned'] = aligned
      return output
    print(json.dumps(check_bam_file('${bam}', 10000)))
    EOF

    read -r kinetics base_modification aligned <<< "\$(python3 ./detect_bam_tags.py | jq -r '. | [.kinetics, .base_modification, .aligned] | @tsv')"

    if [ "\$aligned" = true ]; then
      echo "Input ${bam} is already aligned.  Alignments and haplotype tags will be stripped."
    fi

    if [ "\$base_modification" = false ]; then
      echo "Input ${bam} does not contain base modification tags.  5mCpG pileups will not be generated."
    fi

    if [ "\$kinetics" = true ]; then
      echo "Input ${bam} contains consensus kinetics tags. Kinetics will be stripped from the output."
    fi


    # reset BAM and strip kinetics/haplotype tags if present
    if [ "\$aligned" = true ] || [ "\$kinetics" = true ]; then
      samtools --version
      samtools reset \
        ${threads > 0 ? "-@ $threads" : ""} \
        --remove-tag fi,ri,fp,rp,ip,pw,HP,PS,PC \
        -o ${movie}.reset.bam \
        ${bam}
        INBAM=${movie}.reset.bam
    fi

    # if chunking is desired, index the input BAM and list ZMWs
    if [ "${meta.max_reads_per_alignment_chunk}" -gt "1" ]; then
      pbindex --version
      pbindex --num-threads ${threads} \$INBAM

      zmwfilter --version
      zmwfilter --num-threads ${threads} --show-all \$INBAM > ${movie}.zmws.txt

      read -r n_records <<< "\$(wc -l ${movie}.zmws.txt | cut -f1 -d' ')"

      # if the number of ZMWs is greater than the chunk size, split the input BAM
      if [ "\$n_records" -gt "${meta.max_reads_per_alignment_chunk}" ]; then
        split --version
        split \
          --verbose \
          --lines=${meta.max_reads_per_alignment_chunk} \
          --numeric-suffixes \
          ${movie}.zmws.txt \
          chunk_

        parallel --version
        # shellcheck disable=SC2012
        ls chunk_* | parallel -v -j ${threads} \
          zmwfilter --num-threads 1 --include {} \$INBAM ${movie}.{}.bam

        # if the input BAM was reset, remove so that it is not included in the output
        rm --force --verbose ${movie}.reset.bam
      fi
    fi
    """
}