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

process SAWFISH_DISCOVER {

    maxForks 1
    cache 'lenient'

    // Set batch name and sample id to tag
    tag { meta.batch == '' ? "${meta.id}" : "${meta.batch}_${meta.id}_${meta.build}" }

    // Do not publish data

    input:
    tuple val(meta), path(resource_bundle), path(example_tfrecords), path(nonvariant_tfrecords)

    output:
    tuple val(meta), path(resource_bundle),
    

    script:
    def threads = 16

    def fasta = resource_bundle[1]
    def sawfish_exclude = resource_bundle[4]

    """
    sawfish --version

    sawfish discover \
      --threads ~{threads} \
      --disable-path-canonicalization \
      --ref ~{basename(ref_fasta)} \
      --bam ~{basename(aligned_bam)} \
      --expected-cn ~{expected_bed} \
      --cnv-excluded-regions ~{exclude_bed} \
      --maf ~{small_variant_vcf} \
      --output-dir ~{out_prefix}

    tar --create --verbose --file ~{out_prefix}.tar ~{out_prefix}
    rm --recursive --force --verbose ~{out_prefix}
    """
}