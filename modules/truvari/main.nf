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

process TRUVARI {

    maxForks 1

    // Set sample id to tag
    tag { "${meta.sample}" }

    // Check batch and save output accordingly
    storeDir { "${launchDir}/.nextflow/store/variant_comparisons/${meta.sample}/${meta.build}/truvari" }

    input:
    tuple val(meta), path(resource_bundle), path(truth_sv), path(query_sv)

    output:
    tuple val(meta), path("*.truvari_merge.vcf"), emit: vcf
    tuple val(meta), path("stats_${meta.sample}/*"), emit: stats
    tuple val(meta), path("stats_${meta.sample}/*.truvari.log.txt"), emit: log

    script:
    def fasta = resource_bundle[1]

    """
    bcftools merge -m none ${truth_sv[0]} ${query_sv[0]} | bgzip > merge.vcf.gz
    bcftools index -t merge.vcf.gz
    truvari collapse -i merge.vcf.gz -o ${meta.sample}.truvari_merge.vcf

    truvari bench \
        -b ${truth_sv[0]} \
        -c ${query_sv[0]} \
        -f ${fasta} \
        -o stats_${meta.sample}/

    mv stats_${meta.sample}/log.txt stats_${meta.sample}/${meta.sample}.truvari.log.txt
    """
}