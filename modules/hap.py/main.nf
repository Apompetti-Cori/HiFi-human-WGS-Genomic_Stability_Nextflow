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
params.pubdir = "hap.py"

/*
================================================================================
Module declaration
================================================================================
*/

process HAPPY {

    maxForks 1

    conda "/usr/local/programs/miniconda3/envs/hap.py"

    // Set batch name and sample id to tag
    tag { meta.batch == '' ? "${meta.id}" : "${meta.batch}_${meta.id}" }

    // Check batch and save output accordingly
    publishDir "${params.outdir}", mode: 'link', saveAs: { filename ->
        return meta.batch == '' ? "${meta.id}/${params.pubdir}/${filename}" : "${meta.batch}/${meta.id}/${params.pubdir}/${filename}"
    }

    input:
    tuple val(meta), path(truth_snv), path(query_snv)
    each path(db)
    each path(bed)
    each fasta
    each path(clean)

    output:
    tuple val(meta), path("stats*"), emit: stats

    script:

    """
    /opt/hap.py/bin/hap.py \
        ${truth_snv[0]} \
        ${query_snv[0]} \
        -f ${bed} \
        -r ${db}/${fasta} \
        -o "stats"
    """
}