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

process MOSDEPTH {

    maxForks 1

    // Set sample id to tag
    tag { "${meta.id}_${meta.build}" }

    storeDir { "${launchDir}/.nextflow/store/${meta.batch}/${meta.id}/${meta.build}/bam_stats" }

    input:
    tuple val(meta), path(resource_bundle), path(bam)

    output:
    tuple val(meta), path("*.mosdepth.summary.txt"), emit: stats
    tuple val(meta), path("*.regions.bed.gz*"), emit: regions

    script:
    def threads = 4
    def threads_flag = threads > 1 ? "--threads " + (threads - 1) : ""
    def out_prefix = "${meta.id}.${meta.build}"

    """
    mosdepth \
        ${threads_flag} \
        --by 500 \
        --no-per-base \
        --use-median \
        ${out_prefix} \
        ${bam[0]}
    """
}