# AWS HealthOmics Conversion: Mutation Calling Workflow

**Date**: 2026-04-06
**Scope**: Convert `nextflow_automation/mutation_calling/` to run on AWS HealthOmics while maintaining local Docker compatibility (dual-mode).
**Approach**: Config-Layer Separation — single codebase, conditional config loading.

---

## 1. Dual-Mode Config Architecture

The pipeline runs in two modes determined by the `$AWS_WORKFLOW_RUN` environment variable (set automatically by HealthOmics):

- **Local mode** (default): Docker containers with bind mounts, local reference files, Nextflow secrets.
- **HealthOmics mode**: ECR containers, S3-staged references, AWS Secrets Manager.

At the end of `nextflow.config`:

```groovy
if ("$AWS_WORKFLOW_RUN") {
    includeConfig 'conf/omics.config'
}
```

### 1.1 Production `nextflow.config` Changes

- Guard global `containerOptions = "-v ${params.ref_dir}:/references"` so it only applies in local mode. The omics config sets `containerOptions = ''` to override it. The `docker.runOptions` (which sets `--user`) is similarly overridden to empty.
- Add default `params.ref_*` paths pointing to `/references/` files for backward compatibility.
- Add missing `extraLongTime` label (bug fix — currently used by 5 processes but undefined in production config).
- Add conditional include for `conf/omics.config`.

### 1.2 New `conf/omics.config`

Overrides for HealthOmics:

- **Containers**: ECR URIs for all process containers (via `withName:` selectors).
- **publishDir**: `params.publish_dir = '/mnt/workflow/pubdir'`.
- **Remove unsupported directives**: No `containerOptions`, no `docker.runOptions`.
- **Reference params**: S3 paths for all reference files.
- **Secrets**: `params.use_secrets_manager = true`, `params.oncokb_secret_name = 'oncokb-api-key'`.

---

## 2. Reference File Parameterization

All hardcoded `/references/` paths in process scripts are replaced with Nextflow `path` inputs. The main workflow stages them from params.

### 2.1 Reference Parameters

| Parameter | File | Used By |
|-----------|------|---------|
| `params.ref_fasta` | `Homo_sapiens_assembly38.fasta` | MUTECT2_CALL, GET_PILEUP_SUMMARIES, FILTER_MUTECT_CALLS, MUTECT2_PON, GENOMICS_DB_IMPORT, CREATE_PON, PILEUP, MUSE, VEP, CREATE_MAF, SELECT_VARIANTS |
| `params.ref_fasta_index` | `Homo_sapiens_assembly38.fasta.fai` | Implicit companion to ref_fasta |
| `params.ref_dict` | `Homo_sapiens_assembly38.dict` | MERGE_VCFS |
| `params.gnomad_vcf` | `af-only-gnomad.hg38.vcf.gz` | MUTECT2_CALL, CREATE_PON |
| `params.contamination_vcf` | `small_exac_common_3.hg38.vcf.gz` | GET_PILEUP_SUMMARIES |
| `params.muse_dbsnp` | `common_all_20180418.vcf.gz` | MUSE |
| `params.interval_list` | Already parameterized | MUTECT2_CALL, GET_PILEUP_SUMMARIES, GENOMICS_DB_IMPORT |
| `params.nonsynonymous_list` | `nonsynonymous.txt` | KEEP_NONSYNONYMOUS |
| `params.vep_cache` | VEP offline cache directory | VEP |

### 2.2 Process-Level Changes

Each process that uses reference files adds `path` inputs and replaces hardcoded paths:

**Before**:
```groovy
process MUTECT2_CALL {
    script:
    """
    gatk Mutect2 -R /references/Homo_sapiens_assembly38.fasta ...
    """
}
```

**After**:
```groovy
process MUTECT2_CALL {
    input:
        path ref_fasta
        path gnomad_vcf
        path interval_list
        // ... existing inputs ...

    script:
    """
    gatk Mutect2 -R ${ref_fasta} ...
    """
}
```

### 2.3 Test Mode Simplification

The `if (params.test_mode)` branching inside MUTECT2_CALL, GET_PILEUP_SUMMARIES, and FILTER_MUTECT_CALLS (which switches between production and chr22 reference paths) is removed. Instead, the test config sets params directly:

```groovy
// shared-test.config
params.ref_fasta = "test-data/hg38_chr22.fasta"
params.gnomad_vcf = "test-data/gnomAD_chr22.vcf.gz"
```

### 2.4 Workflow-Level Reference Staging

In `mutation_calling.nf`, each workflow block stages references at the top:

```groovy
workflow MUTATION_CALLING {
    ref_fasta           = file(params.ref_fasta)
    ref_fasta_index     = file(params.ref_fasta_index)
    ref_dict            = file(params.ref_dict)
    gnomad_vcf          = file(params.gnomad_vcf)
    contamination_vcf   = file(params.contamination_vcf)
    muse_dbsnp          = file(params.muse_dbsnp)
    interval_list       = file(params.interval_list)
    nonsynonymous_list  = file(params.nonsynonymous_list)
    vep_cache           = file(params.vep_cache)

    // Process calls pass references explicitly
    MUTECT2_CALL(samples, ref_fasta, ref_fasta_index, gnomad_vcf, interval_list)
    // etc.
}
```

Same pattern for `CREATE_M2_PON`.

---

## 3. VEP Upgrade (v106.1 to v115)

### 3.1 Slim Container

Replace `e10m/vep:106.1` (~15GB with baked-in cache) with `ensemblorg/ensembl-vep:release_115.0` (~1-2GB, no cache).

### 3.2 Cache as External Input

The VEP offline cache (`homo_sapiens_merged/115_GRCh38/`, ~20GB) is stored externally and staged as a `path` input:

```groovy
process VEP {
    input:
        path vep_cache
        path ref_fasta
        // ...

    script:
    """
    vep --offline --dir_cache ${vep_cache} \
        --fasta ${ref_fasta} \
        --fork ${task.cpus} ...
    """
}
```

- **Local mode**: `params.vep_cache = "/path/to/local/vep_cache"`
- **HealthOmics mode**: `params.vep_cache = "s3://bucket/vep-cache/"`

### 3.3 Benefits

- Container size drops ~13GB.
- Cache is versioned independently of the container image.
- Cache upgrades don't require image rebuilds.

### 3.4 Staging Cost

The ~20GB cache is staged per VEP task invocation. HealthOmics provides minimum 1200 GiB storage, so this is not a space concern. It adds a few minutes of staging time per task, which is an acceptable tradeoff.

---

## 4. Secrets Handling (OncoKB)

### 4.1 Current State (Broken)

The ONCOKB process uses three mechanisms:
- `secret 'ONCOKB_API_KEY'` — only works with local/grid executors.
- `containerOptions "--env ONCOKB_TOKEN"` — not supported on HealthOmics.
- `$ONCOKB_API_KEY` in script — env var name doesn't match `containerOptions` (`ONCOKB_TOKEN`). This is a pre-existing bug.

### 4.2 New Dual-Mode Approach

```groovy
process ONCOKB {
    input:
        // ... existing inputs ...

    script:
    def get_key = params.use_secrets_manager
        ? "ONCOKB_API_KEY=\$(aws secretsmanager get-secret-value --secret-id ${params.oncokb_secret_name} --query SecretString --output text)"
        : "ONCOKB_API_KEY=${params.oncokb_api_key}"

    """
    ${get_key}
    python /app/MafAnnotator.py -i ${maf} -o ${sample_id}.${caller}.oncokb.maf \
        -b \$ONCOKB_API_KEY -t BRAIN
    """
}
```

- **Local**: `params.use_secrets_manager = false`. Key passed via `params.oncokb_api_key`.
- **HealthOmics**: `params.use_secrets_manager = true`. Key fetched at runtime from AWS Secrets Manager. Requires IAM role with `secretsmanager:GetSecretValue` permission.

### 4.3 OncoKB Container Modification

The `e10m/oncokb:3.0.0` image needs `awscli` for Secrets Manager access:

```dockerfile
FROM e10m/oncokb:3.0.0
RUN pip install awscli
```

New image: `e10m/oncokb:3.0.0-awscli` (pushed to ECR).

---

## 5. GenomicsDB Directory Output

### 5.1 Problem

`GENOMICS_DB_IMPORT` outputs a directory (`pon_db/`, `type: 'dir'`). S3-backed staging on HealthOmics can struggle with bare directory outputs.

### 5.2 Solution

Tar the directory at the end of `GENOMICS_DB_IMPORT` and untar at the start of `CREATE_PON`:

```groovy
// GENOMICS_DB_IMPORT
output:
    path "pon_db.tar"

script:
"""
gatk GenomicsDBImport ... --genomicsdb-workspace-path pon_db
tar -cf pon_db.tar pon_db/
"""

// CREATE_PON
input:
    path pon_db_tar

script:
"""
tar -xf ${pon_db_tar}
gatk CreateSomaticPanelOfNormals ... -V gendb://pon_db ...
"""
```

---

## 6. Container & ECR Strategy

### 6.1 Images Requiring ECR Repositories

| Local Image | ECR Repository | Notes |
|-------------|---------------|-------|
| `broadinstitute/gatk:4.2.0.0` | `gatk` | Public, pull and push |
| `quay.io/biocontainers/samtools:1.10--h9402c20_1` | `samtools` | Public |
| `e10m/varscan2:latest` | `varscan2` | Custom |
| `ensemblorg/ensembl-vep:release_115.0` | `vep` | New slim image (replaces e10m/vep:106.1) |
| `e10m/vcf2maf:1.6.19` | `vcf2maf` | Custom |
| `e10m/oncokb:3.0.0-awscli` | `oncokb` | Custom, extended with awscli |
| `staphb/bcftools:1.10.2` | `bcftools` | Public |
| `ubuntu:20.04` | `ubuntu` | Used by KEEP_NONSYNONYMOUS, RENAME_HG38 |

### 6.2 ECR Push Script (`scripts/ecr_push.sh`)

Shell script that:
1. Creates ECR repositories if they don't exist.
2. Pulls public images / tags custom images.
3. Pushes all images to ECR.
4. Outputs ECR URIs for `conf/omics.config`.

### 6.3 Workflow Packaging Script (`scripts/package_omics.sh`)

Zips workflow definition files for HealthOmics upload:
```
mutation_calling.nf
nextflow.config
conf/omics.config
modules/**/*.nf
```

---

## 7. Bug Fixes (Included in Conversion)

### 7.1 Missing `extraLongTime` Label

Add to production `nextflow.config`:
```groovy
withLabel: 'extraLongTime' {
    time = 48.h * task.attempt
}
```

Used by: MUTECT2_CALL, MUSE, PILEUP, VARSCAN2, MUTECT2_PON.

### 7.2 ONCOKB Secret Name Mismatch

The current `containerOptions "--env ONCOKB_TOKEN"` doesn't match the `secret 'ONCOKB_API_KEY'` directive or the `$ONCOKB_API_KEY` script reference. The new approach (Section 4) eliminates this inconsistency entirely.

---

## 8. Testing Strategy

### 8.1 Existing Tests (Unchanged)

nf-test suite in `tests/mutation_calling/modules/` continues to work in local Docker mode. Test config sets `params.ref_*` to `test-data/` paths.

### 8.2 HealthOmics Validation

1. **Static linting**: Run AWS HealthOmics Nextflow linter against packaged ZIP before upload.
2. **Local dry-run**: `nextflow run mutation_calling.nf -entry MUTATION_CALLING -preview` with omics config to verify channel wiring.
3. **Small-scale HealthOmics run**: Upload chr22 test data to S3, run on HealthOmics to validate end-to-end.

### 8.3 Test Config Updates

`shared-test.config` updated to set `params.ref_*` paths for test data:
```groovy
params.ref_fasta = "test-data/hg38_chr22.fasta"
params.gnomad_vcf = "test-data/gnomAD_chr22.vcf.gz"
params.contamination_vcf = "test-data/gnomAD_chr22.vcf.gz"
```

---

## 9. Files Changed

### New Files
- `conf/omics.config` — HealthOmics-specific configuration overrides
- `scripts/ecr_push.sh` — ECR repository creation and image push
- `scripts/package_omics.sh` — ZIP packaging for HealthOmics upload
- `containerization/Dockerfile.oncokb-awscli` — OncoKB image with awscli

### Modified Files
- `mutation_calling.nf` — Reference channel setup, updated process call signatures for both entry points
- `nextflow.config` — Conditional include, `extraLongTime` fix, default ref params, guarded containerOptions
- `modules/mutect2/mutect2_call.nf` — Add ref path inputs, remove test_mode branching
- `modules/mutect2/get_pileup_summaries.nf` — Add ref path inputs, remove test_mode branching
- `modules/mutect2/calculate_contamination.nf` — No reference changes needed
- `modules/mutect2/learn_read_orientation.nf` — No reference changes needed
- `modules/mutect2/filter_mutect_calls.nf` — Add ref path input, remove test_mode branching
- `modules/mutect2_pon/mutect2_pon.nf` — Add ref path inputs
- `modules/mutect2_pon/genomics_db_import.nf` — Add ref path inputs, tar directory output
- `modules/mutect2_pon/create_pon.nf` — Add ref path inputs, untar directory input
- `modules/muse/muse.nf` — Add ref path inputs
- `modules/varscan2/pileup.nf` — Add ref path input
- `modules/varscan2/merge_vcf.nf` — Add ref dict path input
- `modules/shared/select_variants.nf` — Add ref path input
- `modules/shared/vep.nf` — Add ref and vep_cache path inputs, update to VEP 115
- `modules/shared/create_maf.nf` — Add ref path input
- `modules/shared/keep_nonsynonymous.nf` — Add nonsynonymous_list path input
- `modules/shared/oncokb.nf` — Dual-mode secret handling, remove secret/containerOptions directives
- `tests/shared-test.config` — Add ref param defaults for test data

### Unchanged Files
- `make_mc_manifest.py`
- `modules/varscan2/varscan2.nf` — No direct reference file usage
- `modules/shared/index.nf` — No reference files
- `modules/shared/reheader.nf` — No reference files
- `modules/shared/rename_hg38.nf` — No reference files
- All nf-test files (tests still pass via local mode)
- All other workflows (data_processing, cnvkit, consensus_calling)

---

## 10. Sources

- [HealthOmics Workflow Definition Requirements](https://docs.aws.amazon.com/omics/latest/dev/workflow-defn-requirements.html)
- [Nextflow Workflow Definition Specifics](https://docs.aws.amazon.com/omics/latest/dev/workflow-definition-nextflow.html)
- [HealthOmics Workflow Language Versions](https://docs.aws.amazon.com/omics/latest/dev/workflows-lang-versions.html)
- [Ensembl VEP 115 Release](https://www.ensembl.info/2025/09/02/ensembl-115-has-been-released/)
- [Ensembl VEP GitHub Releases](https://github.com/Ensembl/ensembl-vep/releases)
