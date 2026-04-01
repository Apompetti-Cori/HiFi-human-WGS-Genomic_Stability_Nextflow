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

    maxForks 4

    // Set sample id to tag
    tag { "${meta.sample}" }

    storeDir { "${launchDir}/.nextflow/store/variant_comparisons/${meta.sample}/${meta.build}/hap.py/vcf" }

    input:
    tuple val(meta), path(resource_bundle), path(truth_snv), path(query_snv)

    output:
    tuple val(meta), path("confident_regions/*.stats*"), emit: confident_regions
    tuple val(meta), path("all_regions/*.stats*"), emit: all_regions
    tuple val(meta), path("*/*.summary.csv"), emit: summary

    script:
    def fasta = resource_bundle[1]
    def bed = resource_bundle[6]

    """
    mkdir -p confident_regions
    hap.py \
        ${truth_snv[0]} \
        ${query_snv[0]} \
        -f ${bed} \
        -r ${fasta} \
        -o "confident_regions/${meta.sample}.stats.confident_regions"

    mkdir -p all_regions
    hap.py \
        ${truth_snv[0]} \
        ${query_snv[0]} \
        -r ${fasta} \
        -o "all_regions/${meta.sample}.stats.all_regions"
    """
}

process HAPPY_GVCF {

    maxForks 4

    // Set sample id to tag
    tag { "${meta.sample}" }

    storeDir { "${launchDir}/.nextflow/store/variant_comparisons/${meta.sample}/${meta.build}/hap.py/gvcf" }

    input:
    tuple val(meta), path(resource_bundle), path(truth_snv), path(query_snv)

    output:
    tuple val(meta), path("confident_regions/*.stats*"), emit: confident_regions
    tuple val(meta), path("all_regions/*.stats*"), emit: all_regions
    tuple val(meta), path("*/*.summary.csv"), emit: summary

    script:
    def fasta = resource_bundle[1]
    def bed = resource_bundle[6]

    """
    mkdir -p confident_regions
    hap.py \
        ${truth_snv[0]} \
        ${query_snv[0]} \
        -f ${bed} \
        -r ${fasta} \
        --convert-gvcf-to-vcf \
        -o "confident_regions/${meta.sample}.stats.g.confident_regions"

    mkdir -p all_regions
    hap.py \
        ${truth_snv[0]} \
        ${query_snv[0]} \
        -r ${fasta} \
        --convert-gvcf-to-vcf \
        -o "all_regions/${meta.sample}.stats.g.all_regions"
    """
}