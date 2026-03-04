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

process MAKE_EXAMPLES {

    maxForks 1

    // Set batch name and sample id to tag
    tag { meta.batch == '' ? "${meta.id}" : "${meta.batch}_${meta.id}_${meta.build}" }

    // Do not publish data

    input:
    tuple val(shard_index), val(meta), path(resource_bundle), path(bam)
    val(num_shards)

    output:
    path "*.example_tfrecords.tar.gz", emit: tfrecords
    path "*.nonvariant_site_tfrecords.tar.gz", emit: gvcfs

    script:
    def total_deepvariant_tasks = 64
    // defaults tasks: 8
    def tasks_per_shard = total_deepvariant_tasks / num_shards
    def task_start_index = shard_index * tasks_per_shard
    def task_end_index = task_start_index + tasks_per_shard - 1

    def fasta = resource_bundle[1]
    def fasta_index = resource_bundle[2]

    """
    mkdir -p example_tfrecords nonvariant_site_tfrecords

    # echo "DeepVariant version: \$VERSION"

    seq ${task_start_index} ${task_end_index} \
    | parallel \
        --jobs ${tasks_per_shard} \
        --halt 2 \
        /opt/deepvariant/bin/make_examples \
            --checkpoint /opt/models/pacbio \
            --norealign_reads \
            --normalize_reads=True \
            --call_small_model_examples \
            --small_model_indel_gq_threshold "30" \
            --small_model_snp_gq_threshold "25" \
            --small_model_vaf_context_window_size "51" \
            --trained_small_model_path "/opt/smallmodels/pacbio" \
            --trim_reads_for_pileup \
            --vsc_min_fraction_indels 0.12 \
            --pileup_image_width 147 \
            --track_ref_reads \
            --phase_reads \
            --partition_size=25000 \
            --max_reads_per_partition=600 \
            --alt_aligned_pileup=diff_channels \
            --sort_by_haplotypes \
            --parse_sam_aux_fields \
            --min_mapping_quality=1 \
            --mode calling \
            --ref ${fasta} \
            --reads ${bam[0]} \
            --examples example_tfrecords/make_examples.tfrecord@${total_deepvariant_tasks}.gz \
            --gvcf nonvariant_site_tfrecords/gvcf.tfrecord@${total_deepvariant_tasks}.gz \
            --task {}

    tar --gzip --create --verbose --file ${meta.id}.${task_start_index}.example_tfrecords.tar.gz example_tfrecords \
        && rm --recursive --force --verbose example_tfrecords
    tar --gzip --create --verbose --file ${meta.id}.${task_start_index}.nonvariant_site_tfrecords.tar.gz nonvariant_site_tfrecords \
        && rm --recursive --force --verbose nonvariant_site_tfrecords
    """
}