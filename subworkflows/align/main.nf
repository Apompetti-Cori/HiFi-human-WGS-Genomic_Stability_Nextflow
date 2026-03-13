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
include { SAMTOOLS_MERGE } from '../../modules/samtools/merge.nf'

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

workflow ALIGN {
    take:
        sample_table

    main:
    // Create an empty channel for multiqc input
    def multiqc_ch = channel.empty()

    // Create input channel for preprocessing samples
    input_ch = createPreprocessChannel(sample_table)

    // Create genome channels to merge to preprocessed bams
    genome_ch = createGenomeChannel(sample_table, params.genomes)

    
    // Check whether the final output of this subworkflow exists:
    check_ch = genome_ch
        .map { meta, ref, build ->
            def pattern = "${launchDir}/.nextflow/store/${meta.batch}/${meta.id}/**/${meta.id}.${build}.merged.bam*"
            def hit = file(pattern)

            return [meta, ref, build, hit]
        }
        .branch { meta, ref, build, hit ->
            //  If hit is not empty, it exists in storeDir
            exists: !hit.isEmpty()
            process: hit.isEmpty()
        }
    
    
    
    // If so, recreate SAMTOOLS_MERGE channel
    exist_ch = check_ch.exists.map { meta, ref, build, hit ->

        def new_meta = meta + [build: build]
        def new_ref = [
                file(ref.db),
                file(ref.fasta),
                file(ref.fasta_index),
                file(ref.pbindex),
                file(ref.sawfish_exclude),
                file(ref.sawfish_expect)
            ]
            
        return [new_meta, new_ref, hit]
    }

    // If not, run SPLIT_INPUT_BAM and PBMM2_ALIGN on these samples
    process_ch = check_ch.process.map { meta, ref, build, hit -> 
        // Reconstruct the input for SPLIT_INPUT_BAM
        return [ meta ]
    }
    .unique()

    process_ch = input_ch
        .combine(process_ch, by: 0)

    // Check which build was not aligned to
    check_genome_ch = check_ch.process.map { meta, ref, build, hit ->
        def id = build + "_" + meta.id
        return [ id, meta, ref]
    }
    .unique()

    // Whitelist genome channel
    genome_ch = genome_ch 
        .map{ meta, ref, build ->
            def id = build + "_" + meta.id
            return [ id, meta, ref, build ]
        }
        .combine(check_genome_ch, by: 0)
        .map{ id, m1, r1, build, m2, r2 ->
            return [ m1, r1, build ]
        }


    // If process_ch has samples inside it run them through the alignment steps
    // Split bams from each sample into smaller bams for aligning
    SPLIT_INPUT_BAM(process_ch)
    split_ch = SPLIT_INPUT_BAM.out.bam
       .transpose()

    split_genome_ch = split_ch
        .combine(genome_ch, by: 0)
        .map{ meta, bam, ref, build ->

            def new_meta = meta + [
                build : build
            ]

            def new_ref = [
                    file(ref.db),
                    file(ref.fasta),
                    file(ref.fasta_index),
                    file(ref.pbindex),
                    file(ref.sawfish_exclude),
                    file(ref.sawfish_expect)
                ]

            return [new_meta, new_ref, bam]
        }

    // Align each split bam separately
    PBMM2_ALIGN(split_genome_ch)

    // Merge split bam alignments
    align_ch = PBMM2_ALIGN.out.bam
        .groupTuple(by: [0])
        .map{ m, g, b ->
            return [m, g[1], b]
        }

    SAMTOOLS_MERGE(align_ch)

    bam_ch = SAMTOOLS_MERGE.out.bam.collect(flat: false).flatMap().concat(exist_ch)

    emit:
        bam_ch = bam_ch
}