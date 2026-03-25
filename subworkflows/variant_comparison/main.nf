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
params.num_shards = 8

/*
================================================================================
Include modules to main pipeline
================================================================================
*/
include { HAPPY } from '../../modules/hap.py/main.nf'
include { JASMINE } from '../../modules/jasmine/main.nf'

/*
================================================================================
Include functions to main pipeline
================================================================================
*/
include { groupBySample } from '../../functions/main.nf'

/*
================================================================================
Workflow declaration
================================================================================
*/

workflow VARIANT_COMPARISON {
    take:
        snv_ch
        sv_ch

    main:
    snv_grouped = groupBySample(snv_ch)
    sv_grouped = groupBySample(sv_ch)

    HAPPY
}