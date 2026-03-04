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

process PBMM2_ALIGN {

    maxForks 2
    cache 'lenient'

    // Set batch name and sample id to tag
    tag { meta.batch == '' ? "${meta.id}" : "${meta.batch}_${meta.id}_${meta.build}" }

    // Do not publish data

    input:
    tuple val(meta), path(resource_bundle), path(bam)

    output:
    tuple val(meta), path(resource_bundle), path("*.aligned.bam"), emit: bam

    script:
    def threads = 32
    def movie = bam.baseName
    
    def db = resource_bundle[0]
    def fasta = resource_bundle[1]
    def fasta_index = resource_bundle[2]
    def pbindex = resource_bundle[3]

    """
    pbmm2 align \
        --num-threads ${threads} \
        --sort-memory 4G \
        --preset HIFI \
        --sample ${meta.id} \
        --log-level INFO \
        --sort \
        --strip \
        --min-length 50 \
        ${pbindex} \
        ${bam} \
        ${meta.id}.${movie}.${meta.build}.aligned.bam
    """
}