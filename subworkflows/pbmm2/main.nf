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
Configurable variables for pipeline
================================================================================
*/

/*
================================================================================
Include modules to main pipeline
================================================================================
*/
include { SPLIT_INPUT_BAM } from '../../modules/split_input_bam/main.nf'
include { PBMM2_ALIGN } from '../../modules/pbmm2_align/main.nf'
include { SAMTOOLS_MERGE } from '../../modules/samtools_merge/main.nf'

/*
================================================================================
Include functions to main pipeline
================================================================================
*/
include { createPreprocessChannel } from '../../functions/main.nf'
include { createGenomeChannel } from '../../functions/main.nf'

/*
================================================================================
Workflow declaration
================================================================================
*/

workflow PBMM2 {
    take:
        sample_table

    main:
    // Create an empty channel for multiqc input
    def multiqc_ch = channel.empty()

    // Create input channel for preprocessing samples
    input_ch = createPreprocessChannel(sample_table)

    // Print out which samples and batches are being processed
    input_ch
        .map { meta, _bam -> meta.batch }
        .unique()
        .collect()
        .subscribe { list -> 
            println "Processing batches: ${list.join(', ')}" 
        }

    input_ch
        .map { meta, _bam -> meta.id }
        .unique()
        .collect()
        .subscribe { list -> 
            println "Processing samples: ${list.join(', ')}" 
        }

    // Split bams from each sample into smaller bams for aligning 
    SPLIT_INPUT_BAM(input_ch)
    split_ch = SPLIT_INPUT_BAM.out.bam
        .transpose()
    
    // Create genome channels to merge to preprocessed bams
    genome_ch = createGenomeChannel(sample_table, params.genomes)

    // Align each split bam separately
    split_ch = genome_ch
        .cross(split_ch)
        .map{ g, s ->
            new_meta = g[0] + [
                build: g[2]
            ]
            genome = g[1]
            bam = s[1]
            db = file(genome.db)
            fasta = file(genome.fasta)
            pbindex = file(genome.pbindex)

            return [new_meta, [db, fasta, pbindex], bam]
        }
    
    PBMM2_ALIGN(split_ch)

    // Merge split bam alignments
    align_ch = PBMM2_ALIGN.out.bam

    align_ch.view()
    //SAMTOOLS_MERGE(align_ch)
}