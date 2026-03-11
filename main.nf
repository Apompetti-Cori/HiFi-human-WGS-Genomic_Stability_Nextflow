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
Configurable variables for pipeline
================================================================================
*/

params.sample_table = false

/*
================================================================================
Include modules to main pipeline
================================================================================
*/

/*
================================================================================
Include functions to main pipeline
================================================================================
*/

/*
================================================================================
Include subworkflows to main pipeline
================================================================================
*/

include { ALIGN } from './subworkflows/align/main.nf'
include { VARIANT_CALLING } from './subworkflows/variant_calling/main.nf'

/*
================================================================================
Workflow declaration
================================================================================
*/

workflow {

    // Create an empty channel for multiqc input
    def multiqc_ch = channel.empty()
    
    // Run PBMM2 subworkflow
    ALIGN(params.sample_table)

    // Run VARIANT_CALLING subworkflow
    VARIANT_CALLING(ALIGN.out.bam_ch)
}