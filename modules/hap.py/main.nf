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

process HAPPY {

    maxForks 1

    // Set sample id to tag
    tag { "${meta.id}" }

    storeDir { "${launchDir}/.nextflow/store/variant_comparisons/${meta.id}/${meta.build}/hap.py" }

    input:
    tuple val(meta), path(resource_bundle), path(truth_snv), path(query_snv)

    output:
    tuple val(meta), path("stats*"), emit: stats

    script:
    def fasta = resource_bundle[1]
    def bed = resource_bundle[6]

    """
    /opt/hap.py/bin/hap.py \
        ${truth_snv[0]} \
        ${query_snv[0]} \
        -f ${bed} \
        -r ${fasta} \
        -o "stats"
    """
}