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

process HIPHASE {

    maxForks 2
    cache 'lenient'

    // Set batch name and sample id to tag
    tag { meta.batch == '' ? "${meta.id}" : "${meta.batch}_${meta.id}_${meta.build}" }

    storeDir { "${launchDir}/.nextflow/store/${meta.batch}/${meta.id}/${meta.build}/hiphase" }

    input:
    tuple val(meta), path(resource_bundle), path(bam), path(small_variant_vcf)

    output:
    tuple val(meta), path(resource_bundle), path("*.hiphase.vcf.gz*"), emit: vcf
    tuple val(meta), path(resource_bundle), path("*.haplotagged.bam*"), emit: bam
    
    script: 
    def threads = 16

    def fasta = resource_bundle[1]

    """
    hiphase --version

    hiphase --threads ${threads} \
      --sample-name ${meta.id} \
      --vcf ${small_variant_vcf[0]} \
      --reference ${fasta} \
      --output-vcf "${meta.id}.${meta.build}.hiphase.vcf.gz"\
      --bam ${bam[0]} \
      --output-bam ${meta.id}.${meta.build}.haplotagged.bam \
      --summary-file ${meta.id}.${meta.build}.hiphase.stats.tsv \
      --blocks-file ${meta.id}.${meta.build}.hiphase.blocks.tsv \
      --haplotag-file ${meta.id}.${meta.build}.hiphase.haplotags.tsv

    gzip ${meta.id}.${meta.build}.hiphase.haplotags.tsv
    """
}