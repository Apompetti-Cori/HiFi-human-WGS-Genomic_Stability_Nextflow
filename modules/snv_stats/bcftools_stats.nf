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

process BCFTOOLS_STATS {

    maxForks 1

    // Set sample id to tag
    tag { "${meta.id}_${meta.build}" }

    storeDir { "${launchDir}/.nextflow/store/${meta.batch}/${meta.id}/${meta.build}/snv_stats" }

    input:
    tuple val(meta), path(resource_bundle), path(vcf)

    output:
    tuple val(meta), path("*.small_variants.vcf.stats.txt"), emit: stats

    script:
    def fasta = resource_bundle[1]

    """
    bcftools norm \
        --fasta-ref ${fasta} \
        --multiallelics - \
        ${vcf} 2>/dev/null \
    | bcftools view \
        --apply-filters .,PASS \
        --exclude 'GQ<20.0 || GT="ref" || GT="mis" || ALT="."' \
        --trim-alt-alleles \
        - \
    | bcftools stats \
        --samples ${meta.id} \
        --fasta-ref ${fasta} \
        - \
    > ${meta.id}.${meta.build}.small_variants.vcf.stats.txt
    """
}