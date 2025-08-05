#!/bin/bash

nextflow run cnvkit.nf \
--with-docker -with-trace \
--base_dir /media/graeberlab/wdtwo/dmach/batch20-bams/ \
--ref_dir /media/graeberlab/wdtwo/dmach/references \
--batch_number 20
