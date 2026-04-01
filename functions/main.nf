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
            def sex = row.sex ?: "FEMALE"
            def bam = files(row.bam_path, glob: true, checkIfExists: true).sort{ file -> file.name }
            def max_reads_per_alignment_chunk = row.max_reads_per_alignment_chunk ?: 500000
            
            def meta = [
                id : id,
                sample: sample,
                batch : batch,
                condition : condition,
                sex : sex,
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
            def sex = row.sex ?: "FEMALE"
            def max_reads_per_alignment_chunk = row.max_reads_per_alignment_chunk ?: 500000
            def db = row.genome ? genomes[ row.genome ].db ?: false : false
            def fasta = row.genome ? genomes[ row.genome ].fasta ?: false : false
            def fasta_index = row.genome ? genomes[ row.genome ].fasta_index ?: false : false
            def pbindex = row.genome ? genomes[ row.genome ].pbindex ?: false : false
            def sawfish_exclude = row.genome ? genomes[ row.genome ].sawfish_exclude ?: false : false
            def sawfish_expect = row.genome ? genomes[ row.genome ].sawfish_expect[sex] ?: false : false
            def happy_filter = row.genome ? genomes[ row.genome ].happy_filter ?: false : false
            
            def meta = [
                id : id,
                sample: sample,
                batch : batch,
                condition : condition,
                sex : sex,
                max_reads_per_alignment_chunk : max_reads_per_alignment_chunk
            ]

            def genome = [
                file(db),
                file(fasta),
                file(fasta_index),
                file(pbindex),
                file(sawfish_exclude),
                file(sawfish_expect),
                file(happy_filter)
            ]

            [meta, genome, row.genome]
        }
        .unique()

    return input_ch
}

def groupBySample(vcf_ch){
    def output = vcf_ch
        .map{meta, ref, vcf ->
            def sample = meta.sample

            return [sample, meta, ref, vcf]
        }
        .groupTuple()
        .map { _sample, meta_list, ref_list, vcf_list ->

            // Zip the lists together
            def zipped = [meta_list, ref_list, vcf_list].transpose()
            
            zipped.sort { item -> 
                item[0].condition == 'WB' ? 0 : 1
            }
            
            // Return them back into independent, safely sorted lists
            def sorted_metas = zipped.collect {it -> it[0] }
            def sorted_refs  = zipped.collect {it -> it[1] }
            def sorted_vcfs  = zipped.collect {it -> it[2] }
            def meta = sorted_metas[0]
            def new_meta = [
                sample: meta.sample,
                batch: "variant_comparison",
                build: meta.build,
                sex: meta.sex
            ]
            
            // Return the newly sorted tuple
            return [new_meta, sorted_refs[0], sorted_vcfs[0], sorted_vcfs[1]]
        }

    return output
}