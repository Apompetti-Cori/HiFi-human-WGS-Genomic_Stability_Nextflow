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
include { MULTIQC } from '../../modules/multiqc/main.nf'

/*
================================================================================
Include functions to main pipeline
================================================================================
*/

/*
================================================================================
Workflow declaration
================================================================================
*/

workflow QUALITY_CONTROL {
    take:
        mqc_ch

    main:
    multiqc_config = channel.fromPath("${projectDir}/modules/multiqc/multiqc_config.yaml")

    mqc_ch = mqc_ch
        .flatMap()
        .map{ meta, file ->
            def key = [batch: meta.batch, build: meta.build]
            return [key, file]
        }
        .groupTuple(by: 0)
        .map{ key, files ->
            return [key, files.flatten()]
        }

    MULTIQC(
        mqc_ch,
        multiqc_config
    )

}