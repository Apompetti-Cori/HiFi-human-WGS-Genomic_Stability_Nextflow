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
include { MAKE_EXAMPLES } from '../../modules/deepvariant/make_examples.nf'
include { DEEPVARIANT_CALL_VARIANTS } from '../../modules/deepvariant/call_variants.nf'
include { DEEPVARIANT_POSTPROCESS } from '../../modules/deepvariant/postprocess.nf'
include { SAWFISH_DISCOVER } from '../../modules/sawfish/discover.nf'

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

    // Run MAKE_EXAMPLES
    MAKE_EXAMPLES(
        shard_indices_ch,
        params.num_shards
    )

    // Collect MAKE_EXAMPLES output to be processed through DEEPVARIANT_CALL_VARIANTS
    examples_collect_ch = MAKE_EXAMPLES.out.tfrecords
        .groupTuple()
        .map{ meta, ref, ex, gvcf ->
            return [meta, ref[0], ex, gvcf]
        }
    
    // Run DEEPVARIANT_CALL_VARIANTS
    DEEPVARIANT_CALL_VARIANTS(
        examples_collect_ch
    )

    call_variants_ch = DEEPVARIANT_CALL_VARIANTS.out.tfrecords
        .collect(flat: false)
    
    call_variants_ch.view()

    // Run DEEPVARIANT_POSTPROCESS

    // Combine bams with called variants to feed into SAWFISH_DISCOVER

    // Run SAWFISH_CALL
}