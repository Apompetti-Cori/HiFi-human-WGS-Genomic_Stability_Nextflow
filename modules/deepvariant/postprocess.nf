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

process DEEPVARIANT_POSTPROCESS {

    maxForks 1
    cache 'lenient'

    // Set batch name and sample id to tag
    tag { meta.batch == '' ? "${meta.id}" : "${meta.batch}_${meta.id}_${meta.build}" }

    // Do not publish data

    input:
    tuple val(meta), path(resource_bundle), path(called_tfrecords), path(example_tfrecords), path(nonvariant_tfrecords)

    output:

    script:
    def total_deepvariant_tasks = 64
    def threads = 2

    def fasta = resource_bundle[1]
    def fasta_index = resource_bundle[2]

    """
    tar --no-same-owner --gzip --extract --verbose --file "~{tfrecords_tar}"

    for tfrecord_tar in *.example_tfrecords.tar.gz; do
        tar --no-same-owner --gzip --extract --verbose --file "\$tfrecord_tar"
    done

    for tfrecord_tar in *.nonvariant_site_tfrecords.tar.gz; do
        tar --no-same-owner --gzip --extract --verbose --file "\$tfrecord_tar"
    done

    /opt/deepvariant/bin/postprocess_variants \
      --cpus ~{threads} \
      --vcf_stats_report=false \
      --ref ~{ref_fasta} \
      --infile call_variants_output.tfrecord.gz \
      --outfile ${meta.id}.${meta.build}.small_variants.vcf.gz \
      --small_model_cvo_records "example_tfrecords/make_examples_call_variant_outputs.tfrecord@${total_deepvariant_tasks}.gz" \
      --nonvariant_site_tfrecord_path "nonvariant_site_tfrecords/gvcf.tfrecord@${total_deepvariant_tasks}.gz" \
      --gvcf_outfile ${meta.id}.${meta.build}.small_variants.g.vcf.gz

    # Filter for only PASS variants
    bcftools view \
    ~{if threads > 1 then "--threads " + (threads - 1) else ""} \
    --exclude-uncalled \
    --output-type z \
    --output-file ~{sample_id}.~{ref_name}.small_variants.passing.vcf.gz \
    ~{sample_id}.~{ref_name}.small_variants.vcf.gz

    mv --verbose ~{sample_id}.~{ref_name}.small_variants.passing.vcf.gz ~{sample_id}.~{ref_name}.small_variants.vcf.gz
    bcftools index --tbi --force \
      ~{if threads > 1 then "--threads " + (threads - 1) else ""} \
      ~{sample_id}.~{ref_name}.small_variants.vcf.gz

    rm --verbose call_variants_output*.tfrecord.gz \
    && rm --recursive --force --verbose nonvariant_site_tfrecords example_tfrecords
    """
}