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

process JASMINE {

    maxForks 1
    cpus 4

    // Set sample id to tag
    tag { "${meta.id}" }

    // Check batch and save output accordingly
    storeDir { "${launchDir}/.nextflow/store/variant_comparisons/${meta.id}/${meta.build}/jasmine" }

    input:
    tuple val(meta), path(resource_bundle), path(truth_sv), path(query_sv)

    output:
    tuple val(meta), path("*.jasmine.vcf*"), emit: vcf

    script:

    """
    bcftools view ${truth_sv[0]} -o ${meta.id}.truth.vcf
    bcftools view ${query_sv[0]} -o ${meta.id}.query.vcf

    realpath ${meta.id}.truth.vcf > ${meta.id}.fofn
    realpath ${meta.id}.query.vcf >> ${meta.id}.fofn

    jasmine \
        threads=${task.cpus} \
        file_list="${meta.id}.fofn" \
        out_dir="./preprocessed_vcfs/" \
        out_file="${meta.id}.jasmine.vcf"
    """
}