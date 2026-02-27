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

process SAMTOOLS_MERGE {

    maxForks 2
    cpus 8

    // Set batch name and sample id to tag
    tag { meta.batch == '' ? "${meta.id}" : "${meta.batch}_${meta.id}" }

    // Do not publish data

    input:
    tuple val(meta), path(resource_bundle), path(bams)

    output:
    tuple val(meta), path(resource_bundle), path("*.merged.bam"), emit: bam

    script:
    def threads = task.cpus > 1 ? task.cpus - 1 : 0
    def db = resource_bundle[0]
    def fasta = resource_bundle[1]
    def pbindex = resource_bundle[2]
    def bam_files = bams.join(' ')

    """
    printf "%s\\n" ${bam_files} > bam_list.txt
    samtools merge -@ ${threads} -b bam_list.txt ${meta.id}.${meta.build}.merged.bam
    """
}