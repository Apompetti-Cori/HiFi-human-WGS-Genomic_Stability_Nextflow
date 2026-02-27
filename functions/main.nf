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
Function declaration
================================================================================
*/
def createInputChannel(String sample_table) {
    // Channel for the samplesheet
    def ch_samplesheet = channel.fromPath(sample_table)

    def input_ch = ch_samplesheet
        .splitCsv(header:true)
        .map{ row ->

            def id = row.sample
            def batch = row.batch
            def condition = row.condition
            def bam = file(row.bam_path, checkIfExists: false).sort{ file -> file.name }
            
            def meta = [
                id : id,
                batch : batch,
                condition : condition
            ]

            [meta, bam]
        }

    return input_ch
}

def createPreprocessChannel(String sample_table) {
    // Channel for the samplesheet
    def ch_samplesheet = channel.fromPath(sample_table)

    def input_ch = ch_samplesheet
        .splitCsv(header:true)
        .map{ row ->

            def id = row.sample_id
            def sample = row.sample
            def batch = row.batch
            def condition = row.condition
            def bam = file(row.bam_path, checkIfExists: false).sort{ file -> file.name }
            def max_reads_per_alignment_chunk = row.max_reads_per_alignment_chunk ?: 500000
            
            def meta = [
                id : id,
                sample: sample,
                batch : batch,
                condition : condition,
                max_reads_per_alignment_chunk : max_reads_per_alignment_chunk
            ]

            [meta, bam]
        }
        .unique()
        .transpose()

    return input_ch
}

def createGenomeChannel(String sample_table, Map genomes) {
    // Channel for the samplesheet
    def ch_samplesheet = channel.fromPath(sample_table)

    def input_ch = ch_samplesheet
        .splitCsv(header:true)
        .map{ row ->

            def id = row.sample_id
            def sample = row.sample
            def batch = row.batch
            def condition = row.condition
            def max_reads_per_alignment_chunk = row.max_reads_per_alignment_chunk ?: 500000
            def db = row.genome ? genomes[ row.genome ].db ?: false : false
            def fasta = row.genome ? genomes[ row.genome ].fasta ?: false : false
            def pbindex = row.genome ? genomes[ row.genome ].pbindex ?: false : false
            
            def meta = [
                id : id,
                sample: sample,
                batch : batch,
                condition : condition,
                max_reads_per_alignment_chunk : max_reads_per_alignment_chunk
            ]

            def genome = [
                db : db,
                fasta : fasta,
                pbindex : pbindex
            ]

            [meta, genome, row.genome]
        }
        .unique()

    return input_ch
}