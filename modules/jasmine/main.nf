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
params.pubdir = "jasmine"

/*
================================================================================
Module declaration
================================================================================
*/

process JASMINE {

    maxForks 1
    cpus 4

    conda "/usr/local/programs/miniconda3/envs/jasmine"

    // Set batch name and sample id to tag
    tag { meta.batch == '' ? "${meta.id}" : "${meta.batch}_${meta.id}" }

    // Check batch and save output accordingly
    publishDir "${params.outdir}", mode: 'link', saveAs: { filename ->
        return meta.batch == '' ? "${meta.id}/${params.pubdir}/${filename}" : "${meta.batch}/${meta.id}/${params.pubdir}/${filename}"
    }

    input:
    tuple val(meta), path(truth_sv), path(query_sv)
    each path(db)
    each path(bed)
    each fasta
    each path(clean)

    output:
    tuple val(meta), path("*.jasmine.vcf*"), emit: reads

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