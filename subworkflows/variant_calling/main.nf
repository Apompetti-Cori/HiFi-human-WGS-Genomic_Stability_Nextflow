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
include { MAKE_EXAMPLES } from '../../modules/make_examples/main.nf'

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

workflow VARIANT_CALLING {
    take:
        bam_ch

    main:
    // Create an empty channel for multiqc input
    def multiqc_ch = channel.empty()

    // Scatter job across shards to speed up process
    shard_indices = Channel.of( 0..(params.num_shards - 1) )
    shard_indices_ch = shard_indices.combine(
        bam_ch
    )

    MAKE_EXAMPLES(
        shard_indices_ch,
        params.num_shards
    )
}