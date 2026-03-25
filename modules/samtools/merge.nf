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

    maxForks 4
    cache 'lenient'

    // Set batch name and sample id to tag
    tag { meta.batch == '' ? "${meta.id}" : "${meta.batch}_${meta.id}_${meta.build}" }

    // Do not publish data
    storeDir "${launchDir}/.nextflow/store/${meta.batch}/${meta.id}/${meta.build}/samtools_merge"

    input:
    tuple val(meta), path(resource_bundle), path(bams)

    output:
    tuple val(meta), path(resource_bundle), path("*.merged.bam*"), emit: bam

    script:
    def threads = 8
    def bam_files = bams.join(' ')

    """
    printf "%s\\n" ${bam_files} > bam_list.txt
    samtools merge -@ ${threads} -b bam_list.txt ${meta.id}.${meta.build}.merged.bam
    samtools index ${meta.id}.${meta.build}.merged.bam
    """
}