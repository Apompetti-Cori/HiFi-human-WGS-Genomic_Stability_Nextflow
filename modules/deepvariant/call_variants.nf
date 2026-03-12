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

process DEEPVARIANT_CALL_VARIANTS {

    maxForks 1
    cache 'lenient'

    // Set batch name and sample id to tag
    tag { meta.batch == '' ? "${meta.id}" : "${meta.batch}_${meta.id}_${meta.build}" }

    // Do not publish data

    input:
    tuple val(meta), path(resource_bundle), path(example_tfrecords), path(nonvariant_tfrecords)

    output:
    tuple val(meta), path(resource_bundle), path("*.call_variants_output.tar.gz"), path(example_tfrecords), path(nonvariant_tfrecords)

    script:
    def total_deepvariant_tasks = 64
    def writer_threads = 8

    """
    for tfrecord_tar in *.example_tfrecords.tar.gz; do
        tar --no-same-owner --gzip --extract --verbose --file "\$tfrecord_tar"
    done

    /opt/deepvariant/bin/call_variants \
        --writer_threads ${writer_threads} \
        --outfile call_variants_output.tfrecord.gz \
        --examples "example_tfrecords/make_examples.tfrecord@${total_deepvariant_tasks}.gz" \
        --checkpoint "/opt/models/pacbio"

    tar --gzip --create --verbose --file ${meta.id}.${meta.build}.call_variants_output.tar.gz call_variants_output*.tfrecord.gz \
    && rm --verbose call_variants_output*.tfrecord.gz \
    && rm --recursive --force --verbose example_tfrecords
    """
}