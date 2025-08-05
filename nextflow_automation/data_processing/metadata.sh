#!/usr/bin/env bash

python make_metadata_sheet.py \
-f "/media/graeberlab/wdtwo/dmach/test_fastqs/nf-batch-18/raw_fastqs" \
-b 18 \
-p "Illumina_NovaSeq6000" \
-s "TCGB" \
-m "/media/graeberlab/wdtwo/dmach/wes_pipeline/revamp_files/nextflow_automation/data_processing/metadata/SequencingPrep.xlsx" \
-o "/media/graeberlab/wdtwo/dmach/wes_pipeline/revamp_files/nextflow_automation/data_processing"
