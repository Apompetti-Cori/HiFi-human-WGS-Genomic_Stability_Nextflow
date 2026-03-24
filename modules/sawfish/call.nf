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

process SAWFISH_CALL_SINGLE {

    maxForks 4
    cache 'lenient'

    // Set batch name and sample id to tag dynamically within a single closure
    tag { meta.batch == '' ? "${meta.id}" : "${meta.batch}_${meta.id}_${meta.build}" }

    // Set storeDir dynamically within a single closure
    storeDir { "${launchDir}/.nextflow/store/${meta.batch}/${meta.id}/${meta.build}/sawfish_call" }

    input:
    tuple val(meta), path(resource_bundle), path(bam), path(discover_tar)

    output:
    tuple val(meta), path(resource_bundle), path("*.vcf.gz*"), emit: vcf
    
    script:
    def out_prefix = "${meta.id}.${meta.build}.structural_variants"
    
    def threads = 16
    def threads_flag = threads > 1 ? "--threads " + (threads - 1) : ""

    def sawfish_flag = "--sample ${meta.id}.${meta.build}.discover"

    def fasta = resource_bundle[1]

    """
    sawfish --version

    # This loop flawlessly handles 1 or 100 tarballs.
    for tarfile in ${discover_tar}; do
      tar --no-same-owner --extract --verbose --file "\$tarfile"
    done

    # shellcheck disable=SC2068
    # Run joint-call using the dynamically built args
    sawfish joint-call \
      --threads ${threads} \
      --report-supporting-reads \
      ${sawfish_flag} \
      --output-dir ${out_prefix}

    # sawshark annotation
    sawshark \
      --threads \$(( ${threads} / 2 )) \
      --vcf ${out_prefix}/genotyped.sv.vcf.gz \
    | bcftools view - \
      --threads \$(( (${threads} / 2) - 1 )) \
      --output-type z \
      --output ${out_prefix}.vcf.gz

    bcftools index --tbi \
      ${threads_flag} \
      ${out_prefix}.vcf.gz

    # rename the output files to be more informative
    mv --verbose ${out_prefix}/supporting_reads.json.gz ${out_prefix}.supporting_reads.json.gz
    mv --verbose ${out_prefix}/samples/sample????_${meta.id}/copynum.bedgraph ${out_prefix}.copynum.bedgraph
    mv --verbose ${out_prefix}/samples/sample????_${meta.id}/depth.bw ${out_prefix}.depth.bw
    mv --verbose ${out_prefix}/samples/sample????_${meta.id}/gc_bias_corrected_depth.bw ${out_prefix}.gc_bias_corrected_depth.bw
    mv --verbose ${out_prefix}/samples/sample????_${meta.id}/maf.bw ${out_prefix}.maf.bw
    mv --verbose ${out_prefix}/samples/sample????_${meta.id}/copynum.summary.json ${out_prefix}.copynum.summary.json

    # shellcheck disable=SC2086,SC2048
    rm --recursive --force --verbose \$(basename -s .tar "${discover_tar}")
    """
}