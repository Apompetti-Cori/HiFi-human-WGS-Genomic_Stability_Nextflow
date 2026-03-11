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

process DEEPVARIANT_CALL_VARIANTS {

    maxForks 1
    cache 'lenient'

    // Set batch name and sample id to tag
    tag { meta.batch == '' ? "${meta.id}" : "${meta.batch}_${meta.id}_${meta.build}" }

    // Do not publish data

    input:
    tuple val(meta), path(resource_bundle)

    output:

    script:
    def threads = 2

    def fasta = resource_bundle[1]
    def fasta_index = resource_bundle[2]

    """
    """
}