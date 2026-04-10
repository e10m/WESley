#!/usr/bin/env bash
set -euo pipefail

# ECR Push Script for WESley Mutation Calling Pipeline
# Usage: ./ecr_push.sh <AWS_ACCOUNT_ID> <AWS_REGION>
#
# Prerequisites:
#   - AWS CLI configured with appropriate permissions
#   - Docker running locally
#   - All custom images available locally (e10m/*)

ACCOUNT_ID="${1:?Usage: $0 <AWS_ACCOUNT_ID> <AWS_REGION>}"
REGION="${2:?Usage: $0 <AWS_ACCOUNT_ID> <AWS_REGION>}"
ECR_BASE="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# Authenticate Docker to ECR
aws ecr get-login-password --region "${REGION}" | \
    docker login --username AWS --password-stdin "${ECR_BASE}"

# Define images: local_image|ecr_repo:tag
IMAGES=(
    "broadinstitute/gatk:4.2.0.0|gatk:4.2.0.0"
    "quay.io/biocontainers/samtools:1.10--h9402c20_1|samtools:1.10"
    "quay.io/biocontainers/muse:1.0.rc--1|muse:1.0.rc"
    "e10m/varscan2:latest|varscan2:latest"
    "ensemblorg/ensembl-vep:release_115.0|vep:115.0"
    "e10m/vcf2maf:1.6.19|vcf2maf:1.6.19"
    "e10m/oncokb-awscli:3.0.0|oncokb:3.0.0"
    "staphb/bcftools:1.10.2|bcftools:1.10.2"
    "ubuntu:20.04|ubuntu:20.04"
)

for ENTRY in "${IMAGES[@]}"; do
    LOCAL_IMAGE="${ENTRY%%|*}"
    ECR_TAG="${ENTRY##*|}"
    ECR_REPO="${ECR_TAG%%:*}"
    ECR_URI="${ECR_BASE}/${ECR_TAG}"

    echo "=== Processing ${LOCAL_IMAGE} -> ${ECR_URI} ==="

    # Create ECR repository if it doesn't exist
    aws ecr describe-repositories --repository-names "${ECR_REPO}" --region "${REGION}" 2>/dev/null || \
        aws ecr create-repository --repository-name "${ECR_REPO}" --region "${REGION}"

    # Pull public image if needed
    docker pull "${LOCAL_IMAGE}" || true

    # Tag and push
    docker tag "${LOCAL_IMAGE}" "${ECR_URI}"
    docker push "${ECR_URI}"

    echo "=== Done: ${ECR_URI} ==="
    echo ""
done

echo "All images pushed to ECR."
echo ""
echo "Update conf/omics.config with these values:"
echo "  Account ID: ${ACCOUNT_ID}"
echo "  Region: ${REGION}"
echo "  ECR Base: ${ECR_BASE}"