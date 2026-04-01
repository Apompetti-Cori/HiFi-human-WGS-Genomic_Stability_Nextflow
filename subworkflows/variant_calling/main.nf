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
include { SAWFISH_CALL_SINGLE as SAWFISH_CALL } from '../../modules/sawfish/call.nf'
include { HIPHASE } from '../../modules/hiphase/main.nf'
include { BCFTOOLS_STATS } from '../../modules/snv_stats/bcftools_stats.nf'


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

    /*
    ================================================================================
    CHECK FOR OUTPUTS TO SKIP DEEPVARIANT STEPS:
        1) Check for small variant vcf files
        2) For samples not containing small variant vcfs
            - Run through Deepvariant steps
    ================================================================================
    */

    // Check whether Deepvariant output of this subworkflow exists:
    check_ch = bam_ch
        .map { meta, ref, bam ->
            def vcf_path = "${launchDir}/.nextflow/store/${meta.batch}/${meta.id}/${meta.build}/**/${meta.id}.${meta.build}.small_variants.vcf.gz*"
            def vcf = file(vcf_path)

            def gvcf_path = "${launchDir}/.nextflow/store/${meta.batch}/${meta.id}/${meta.build}/**/${meta.id}.${meta.build}.small_variants.g.vcf.gz*"
            def gvcf = file(gvcf_path)

            return [meta, ref, bam, vcf, gvcf]
        }
        .branch { meta, ref, bam, vcf, gvcf ->
            //  If hit is not empty, it exists in storeDir
            exists: !vcf.isEmpty()
            process: vcf.isEmpty()
        }

    exist_ch = check_ch.exists
        .map { meta, ref, bam, vcf, gvcf ->
            return [meta, ref, bam, vcf]
        }

    exist_gvcf_ch = check_ch.exists
        .map { meta, ref, bam, vcf, gvcf ->
            return [meta, ref, gvcf]
        }

    // If not run Deepvariant steps on process_ch
    process_ch = check_ch.process
        .map { meta, ref, bam, vcf, gvcf ->
            return [meta, ref, bam]
        }

    /*
    ================================================================================
    RUN DEEPVARIANT STEPS:
        MAKE_EXAMPLES
        DEEPVARIANT_CALL_VARIANTS
        DEEPVARIANT_POSTPROCESS
    ================================================================================
    */
    
    // Scatter job across shards to speed up MAKE_EXAMPLES
    shard_indices = channel.of( 0..(params.num_shards - 1) )
    shard_indices_ch = shard_indices.combine(
        process_ch
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
        .flatMap()

    // Run DEEPVARIANT_POSTPROCESS
    DEEPVARIANT_POSTPROCESS(
        call_variants_ch
    )

    // Combine bams with called variants to feed into SAWFISH_DISCOVER
    post_ch = DEEPVARIANT_POSTPROCESS.out.vcf
        .collect(flat: false)
        .flatMap()
        .combine(bam_ch, by: 0)
        .map{meta, r1, vcf, r2, bam ->
            return [meta, r1, bam, vcf]
        }
        .concat(exist_ch)

    gvcf_ch = DEEPVARIANT_POSTPROCESS.out.gvcf
        .collect(flat: false)
        .flatMap()
        .concat(exist_gvcf_ch)

     /*
    ================================================================================
    CHECK FOR OUTPUTS TO SKIP SAWFISH STEPS:
        1) Check for structural variant vcf files
        2) For samples not containing structural variant vcfs
            - Run through Sawfish steps
    ================================================================================
    */
    
    // Check whether Deepvariant output of this subworkflow exists:
    check_ch = post_ch
        .map { meta, ref, bam, vcf ->
            def vcf_path = "${launchDir}/.nextflow/store/${meta.batch}/${meta.id}/${meta.build}/**/${meta.id}.${meta.build}.structural_variants.vcf.gz*"
            def sv = file(vcf_path)

            return [meta, ref, bam, vcf, sv]
        }
        .branch { meta, ref, bam, vcf, sv ->
            //  If hit is not empty, it exists in storeDir
            exists: !sv.isEmpty()
            process: sv.isEmpty()
        }

    // 1. Reshape the 'process' channel to only include what's needed to run the tool
    process_ch = check_ch.process
        .map { meta, ref, bam, vcf, sv -> 
            return [meta, ref, bam, vcf] // Drops the empty 'sv' list
        }

    // 2. Reshape the 'exists' channel to only pass along the found SVs
    exist_ch = check_ch.exists
        .map { meta, ref, bam, vcf, sv -> 
            return [meta, ref, sv] // Keeps metadata and the found SV file(s), drops bam/vcf
        }

    /*
    ================================================================================
    RUN SAWFISH STEPS:
        SAWFISH_DISCOVER
        SAWFISH_CALL
    ================================================================================
    */

    // Run SAWFISH_CALL
    SAWFISH_DISCOVER(
        process_ch
    )
    
    if (params.joint_call) {
        discover_ch = SAWFISH_DISCOVER.out
            .collect()
    } else {
        discover_ch = SAWFISH_DISCOVER.out
            .collect(flat: false)
            .flatMap()
    }
    

   SAWFISH_CALL(
        discover_ch
    )

    sv_ch = SAWFISH_CALL.out.vcf
        .collect(flat: false)
        .flatMap()
        .concat(exist_ch)

    /*
    ================================================================================
    CHECK FOR OUTPUTS TO SKIP HIPHASE STEPS:
        1) Check for phased variant vcf files
        2) For samples not containing phased variant vcfs
            - Run through Hiphase steps
    ================================================================================
    */
    
    // Check whether Deepvariant output of this subworkflow exists:
    check_ch = post_ch
        .map { meta, ref, bam, vcf ->
            def phased_vcf_path = "${launchDir}/.nextflow/store/${meta.batch}/${meta.id}/${meta.build}/**/${meta.id}.${meta.build}.hiphase.vcf.gz*"
            def phased_vcf = file(phased_vcf_path)

            return [meta, ref, bam, vcf, phased_vcf]
        }
        .branch { meta, ref, bam, vcf, phased_vcf ->
            //  If hit is not empty, it exists in storeDir
            exists: !phased_vcf.isEmpty()
            process: phased_vcf.isEmpty()
        }

    // 1. Reshape the 'process' channel to only include what's needed to run the tool
    process_ch = check_ch.process
        .map { meta, ref, bam, vcf, phased_vcf ->
            return [meta, ref, bam, vcf] // Drops the empty 'hit' list
        }

    // 2. Reshape the 'exists' channel to only pass along the found VCFs
    exist_ch = check_ch.exists
        .map { meta, ref, bam, vcf, phased_vcf -> 
            return [meta, ref, phased_vcf] // Keeps metadata and the found files
        }

    HIPHASE(
        process_ch
    )

    phase_ch = HIPHASE.out.vcf
        .collect(flat: false)
        .flatMap()
        .concat(exist_ch)

    phase_bam_ch = HIPHASE.out.bam
        .collect(flat: false)
        .flatMap()
        .concat(exist_ch)
    

    BCFTOOLS_STATS(
        phase_ch
    )

    multiqc_ch = multiqc_ch
        .mix(BCFTOOLS_STATS.out.stats)

    emit:
        snv_ch = phase_ch
        gvcf_ch = gvcf_ch
        sv_ch = sv_ch
        bam_ch = phase_bam_ch
        mqc_ch = multiqc_ch

}