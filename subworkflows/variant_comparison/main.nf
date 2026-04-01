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

/*
================================================================================
Include modules to main pipeline
================================================================================
*/
include { HAPPY } from '../../modules/hap.py/main.nf'
include { HAPPY_GVCF } from '../../modules/hap.py/main.nf'
include { JASMINE } from '../../modules/jasmine/main.nf'
include { TRUVARI } from '../../modules/truvari/main.nf'

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
        gvcf_ch

    main:
    def multiqc_ch = channel.empty()

    snv_grouped = groupBySample(snv_ch)
    sv_grouped = groupBySample(sv_ch)
    gvcf_grouped = groupBySample(gvcf_ch)

    // Run SNV comparison using HAPPY
    HAPPY(snv_grouped)

    HAPPY_GVCF(gvcf_grouped)

    // Run SV comparison using TRUVARI
    TRUVARI(sv_grouped)

    // Run SV comparison using JASMINE
    JASMINE(sv_grouped)

    multiqc_ch = multiqc_ch
        .mix(TRUVARI.out.log)
        .mix(HAPPY.out.summary)

    emit:
        mqc_ch = multiqc_ch

}