#!/bin/bash

# Define the command
CMD="nextflow \
-log './.nextflow/pipeline_info/nextflow.log' \
run $(find . -type f -path '*/HiFi-human-WGS-Genomic-Stability_Nextflow_v2/main.nf') \
-resume \
-work-dir $(pwd)/.nextflow/work/ \
-with-dag './.nextflow/pipeline_info/pipeline_dag.svg' \
-with-report './.nextflow/pipeline_info/execution_report.html' \
-with-trace './.nextflow/pipeline_info/execution_trace.txt' \
-profile standard \
--sample_table $(find $(pwd) -type f -name 'sample_table.csv')"

# Print out command
#echo -e "Executing command:\n$CMD"

# Execute command
eval $CMD