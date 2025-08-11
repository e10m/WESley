#!/bin/bash

echo "Pulling Docker containers from Nextflow pipeline..."

images=(
  "quay.io/biocontainers/trim-galore:0.6.6--0"
  "quay.io/biocontainers/bbmap:38.06--0"
  "e10m/bwa-and-samtools:latest"
  "broadinstitute/gatk:4.2.0.0"
  "ubuntu:20.04"
  "quay.io/biocontainers/samtools:1.10--h9402c20_1"
  "e10m/muse:1.0"
  "e10m/varscan2:latest"
  "e10m/vep:103"
  "e10m/vcf2maf:1.6.19"
  "e10m/oncokb:3.0.0"
  "quay.io/biocontainers/cnvkit:0.9.10--pyhdfd78af_0"
)

for image in "${images[@]}"; do
  echo "Pulling $image..."
  docker pull "$image"
  if [ $? -eq 0 ]; then
    echo "✓ Successfully pulled $image"
  else
    echo "✗ Failed to pull $image"
  fi
  echo ""
done

echo "Finished pulling all containers!"