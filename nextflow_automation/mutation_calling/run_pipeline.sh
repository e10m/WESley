#!/bin/bash

export ONCOKB_TOKEN=$(cat /media/graeberlab/wdtwo/dmach/references/oncokb-token.txt)

nextflow run mutation_calling.nf --with-docker -with-trace \
--base_dir "/media/graeberlab/wdtwo/dmach/truncated-bams" \
--batch_number 123