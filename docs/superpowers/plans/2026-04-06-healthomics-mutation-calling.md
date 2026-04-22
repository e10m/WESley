# AWS HealthOmics Mutation Calling Conversion — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the mutation calling Nextflow workflow to run on AWS HealthOmics while maintaining local Docker compatibility (dual-mode).

**Architecture:** Config-layer separation with conditional `includeConfig` via `$AWS_WORKFLOW_RUN`. Reference files become parameterized `path` inputs. ECR containers override local containers via `conf/omics.config`. VEP upgraded from v106.1 to v115 with external cache.

**Tech Stack:** Nextflow DSL2, AWS HealthOmics, Amazon ECR, AWS Secrets Manager, Docker

**Spec:** `docs/superpowers/specs/2026-04-06-healthomics-mutation-calling-design.md`

---

## File Structure

### New Files
| File | Responsibility |
|------|----------------|
| `mutation_calling/conf/omics.config` | HealthOmics-specific overrides (ECR containers, publishDir, S3 ref params, secrets config) |
| `scripts/ecr_push.sh` | Creates ECR repos and pushes all container images |
| `scripts/package_omics.sh` | Zips workflow files for HealthOmics upload |
| `containerization/Dockerfile.oncokb-awscli` | Extends oncokb image with awscli |

### Modified Files
| File | Change Summary |
|------|----------------|
| `mutation_calling/nextflow.config` | Add `extraLongTime` label, default ref params, conditional omics include, guard `containerOptions` |
| `mutation_calling/mutation_calling.nf` | Stage ref files from params, pass to all process calls |
| `modules/mutect2/mutect2_call.nf` | Add ref `path` inputs, remove `test_mode` branching |
| `modules/mutect2/get_pileup_summaries.nf` | Add ref `path` inputs, remove `test_mode` branching |
| `modules/mutect2/filter_mutect_calls.nf` | Add ref `path` input, remove `test_mode` branching |
| `modules/mutect2_pon/mutect2_pon.nf` | Add ref `path` inputs |
| `modules/mutect2_pon/genomics_db_import.nf` | Add ref `path` inputs, tar directory output |
| `modules/mutect2_pon/create_pon.nf` | Add ref `path` inputs, untar directory input |
| `modules/muse/muse.nf` | Add ref `path` inputs |
| `modules/varscan2/pileup.nf` | Add ref `path` input |
| `modules/varscan2/merge_vcf.nf` | Add ref dict `path` input |
| `modules/shared/select_variants.nf` | Add ref `path` input |
| `modules/shared/vep.nf` | Add ref + vep_cache `path` inputs, update to VEP 115 |
| `modules/shared/create_maf.nf` | Add ref `path` input |
| `modules/shared/keep_nonsynonymous.nf` | Add nonsynonymous_list `path` input |
| `modules/shared/oncokb.nf` | Dual-mode secret handling, remove `secret`/`containerOptions` |
| `tests/shared-test.config` | Add `params.ref_*` defaults for test data |

### Unchanged Files
| File | Why |
|------|-----|
| `modules/mutect2/learn_read_orientation.nf` | No reference files used |
| `modules/mutect2/calculate_contamination.nf` | No reference files used |
| `modules/varscan2/varscan2.nf` | No direct reference file usage |
| `modules/shared/index.nf` | No reference files |
| `modules/shared/reheader.nf` | No reference files |
| `modules/shared/rename_hg38.nf` | No reference files |
| `make_mc_manifest.py` | No changes needed |

---

## Task 1: Fix `extraLongTime` bug and add default reference params to `nextflow.config`

**Files:**
- Modify: `nextflow_automation/mutation_calling/nextflow.config`

- [ ] **Step 1: Add `extraLongTime` label and default reference params**

Open `nextflow_automation/mutation_calling/nextflow.config` and make these changes:

1. Add `extraLongTime` after the `shortTime` label (after line 47):

```groovy
      withLabel: 'shortTime' { time = { 8.h * task.attempt } }
      withLabel: 'extraLongTime' { time = { 48.h * task.attempt } }
```

2. Add default reference params in the `params` block (after line 14, before the closing `}`):

```groovy
params {
    output_dir = null
    ref_dir = null
    metadata = null
    cpus = 30
    interval_list = null
    normal_dir = null

    // optional parameters
    help = false
    test_mode = false

    // reference file paths (defaults for local mode using /references mount)
    ref_fasta = "${ref_dir}/Homo_sapiens_assembly38.fasta"
    ref_fasta_index = "${ref_dir}/Homo_sapiens_assembly38.fasta.fai"
    ref_dict = "${ref_dir}/Homo_sapiens_assembly38.dict"
    gnomad_vcf = "${ref_dir}/af-only-gnomad.hg38.vcf.gz"
    gnomad_vcf_index = "${ref_dir}/af-only-gnomad.hg38.vcf.gz.tbi"
    contamination_vcf = "${ref_dir}/small_exac_common_3.hg38.vcf.gz"
    contamination_vcf_index = "${ref_dir}/small_exac_common_3.hg38.vcf.gz.tbi"
    muse_dbsnp = "${ref_dir}/common_all_20180418.vcf.gz"
    nonsynonymous_list = "${ref_dir}/nonsynonymous.txt"
    vep_cache = "/opt/vep/.vep"

    // OncoKB settings
    use_secrets_manager = false
    oncokb_api_key = null
    oncokb_secret_name = "oncokb-api-key"
}
```

3. Guard `containerOptions` so it only applies when `ref_dir` is set (replace line 28):

```groovy
    containerOptions = { params.ref_dir ? "-v ${params.ref_dir}:/references" : "" }
```

4. Guard the ONCOKB `containerOptions` similarly (replace line 80):

```groovy
    withName: ONCOKB {
        container = 'e10m/oncokb:3.0.0'
    }
```

5. Add conditional HealthOmics config at the very end of the file (after the `docker` block, after line 87):

```groovy
// Load HealthOmics overrides when running on AWS HealthOmics
if ("$AWS_WORKFLOW_RUN") {
    includeConfig 'conf/omics.config'
}
```

- [ ] **Step 2: Verify config syntax**

Run: `cd nextflow_automation/mutation_calling && nextflow config -show-profiles .`

Expected: Config prints without errors.

- [ ] **Step 3: Commit**

```bash
git add nextflow_automation/mutation_calling/nextflow.config
git commit -m "fix: add extraLongTime label, default ref params, and HealthOmics conditional include"
```

---

## Task 2: Refactor Mutect2 processes to use parameterized references

**Files:**
- Modify: `nextflow_automation/mutation_calling/modules/mutect2/mutect2_call.nf`
- Modify: `nextflow_automation/mutation_calling/modules/mutect2/get_pileup_summaries.nf`
- Modify: `nextflow_automation/mutation_calling/modules/mutect2/filter_mutect_calls.nf`

- [ ] **Step 1: Refactor `mutect2_call.nf`**

Replace the full process with:

```groovy
/*
mutect2_call.nf module

This module performs the initial GATK Mutect2 variant calling step.
Generates unfiltered variants and F1R2 orientation data for downstream processing.

GATK Version: 4.2.0.0
*/

process MUTECT2_CALL {
    tag "${sample_id}"
    label 'lowCpu'
    label 'medMem'
    label 'extraLongTime'

    input:
    tuple val(sample_id), val(tumor_id), path(tumor_bam), path(tumor_bai), path(tumor_sbi), val(normal_id), path(normal_bam), path(normal_bai)
    path ref_fasta
    path ref_fasta_index
    path gnomad_vcf
    path gnomad_vcf_index
    path interval_list

    output:
    tuple val(sample_id), val(tumor_id), val(normal_id), path("${sample_id}.mutect2.*.vcf"), path("${sample_id}.f1r2.tar.gz"), path("${sample_id}*stats")

    script:
    def normal_args = (normal_bam.size() > 0 ?
        "-I ${normal_bam} -normal ${normal_id}" : "")
    def output_name = (normal_args ? "${sample_id}.mutect2.paired.vcf" : "${sample_id}.mutect2.tumorOnly.vcf")

    """
    gatk Mutect2 \\
        -R ${ref_fasta} \\
        -I ${tumor_bam} \\
        ${normal_args} \\
        --germline-resource ${gnomad_vcf} \\
        -L ${interval_list} \\
        --f1r2-tar-gz ${sample_id}.f1r2.tar.gz \\
        -O $output_name \\
        --genotype-germline-sites true \\
        --genotype-pon-sites true \\
        --downsampling-stride 20 \\
        --max-reads-per-alignment-start 0 \\
        --max-mnp-distance 0 \\
        --max-suspicious-reads-per-alignment-start 6 \\
        -ip 200
    """
}
```

- [ ] **Step 2: Refactor `get_pileup_summaries.nf`**

Replace the full process with:

```groovy
/*
get_pileup_summaries.nf module

This module generates pileup summaries for both tumor and normal samples
to enable contamination estimation in downstream processing.

GATK Version: 4.2.0.0
*/

process GET_PILEUP_SUMMARIES {
    tag "${sample_id}"
    label 'lowCpu'
    label 'lowMem'
    label 'medTime'

    input:
    tuple val(sample_id), val(tumor_id), path(tumor_bam), path(tumor_bai), path(tumor_sbi), val(normal_id), path(normal_bam), path(normal_bai)
    path ref_fasta
    path ref_fasta_index
    path contamination_vcf
    path contamination_vcf_index
    path interval_list

    output:
    tuple val(sample_id), val(tumor_id), val(normal_id), path("${sample_id}.tumor-pileups.table"), path("${sample_id}.normal-pileups.table")

    script:
    def normal_pileup_cmd = (normal_bam.name != 'NO_FILE' && normal_bam.size() > 0 ?
        """
        gatk GetPileupSummaries \\
        -R ${ref_fasta} \\
        -I ${normal_bam} \\
        --interval-set-rule INTERSECTION \\
        -L ${interval_list} \\
        -V ${contamination_vcf} \\
        -L ${contamination_vcf} \\
        -O "${sample_id}.normal-pileups.table"
        """ : "touch ${sample_id}.normal-pileups.table")

    """
    # Get tumor pileup summaries
    gatk GetPileupSummaries \\
    -R ${ref_fasta} \\
    -I ${tumor_bam} \\
    --interval-set-rule INTERSECTION \\
    -L ${interval_list} \\
    -V ${contamination_vcf} \\
    -L ${contamination_vcf} \\
    -O "${sample_id}.tumor-pileups.table"

    # Get normal pileup summaries (if paired mode)
    ${normal_pileup_cmd}
    """
}
```

- [ ] **Step 3: Refactor `filter_mutect_calls.nf`**

Replace the full process with:

```groovy
/*
filter_mutect_calls.nf module

This module applies contamination and orientation bias filtering
to produce the final filtered Mutect2 variant calls.

GATK Version: 4.2.0.0
*/

process FILTER_MUTECT_CALLS {
    tag "${sample_id}"
    label 'lowCpu'
    label 'lowMem'
    label 'shortTime'

    input:
    tuple val(sample_id), val(tumor_id), val(normal_id), path(unfiltered_vcf), path(orientation_model), path(m2_stats), path(contamination_table), path(segments_table)
    path ref_fasta
    path ref_fasta_index

    output:
    tuple val(sample_id), val(tumor_id), val(normal_id), path("${sample_id}.mutect2*filtered.vcf")

    script:
    def output_name = (unfiltered_vcf =~ /paired/ ? "${sample_id}.mutect2.paired.filtered.vcf" : "${sample_id}.mutect2.tumorOnly.filtered.vcf")

    """
    gatk FilterMutectCalls \\
        -V $unfiltered_vcf \\
        -O $output_name \\
        -R ${ref_fasta} \\
        --contamination-table ${contamination_table} \\
        --tumor-segmentation ${segments_table} \\
        --orientation-bias-artifact-priors ${orientation_model} \\
        -stats $m2_stats \\
        --filtering-stats "${sample_id}.filter.stats"
    """
}
```

- [ ] **Step 4: Commit**

```bash
git add nextflow_automation/mutation_calling/modules/mutect2/mutect2_call.nf \
        nextflow_automation/mutation_calling/modules/mutect2/get_pileup_summaries.nf \
        nextflow_automation/mutation_calling/modules/mutect2/filter_mutect_calls.nf
git commit -m "refactor: parameterize reference files in Mutect2 processes"
```

---

## Task 3: Refactor PON processes to use parameterized references

**Files:**
- Modify: `nextflow_automation/mutation_calling/modules/mutect2_pon/mutect2_pon.nf`
- Modify: `nextflow_automation/mutation_calling/modules/mutect2_pon/genomics_db_import.nf`
- Modify: `nextflow_automation/mutation_calling/modules/mutect2_pon/create_pon.nf`

- [ ] **Step 1: Refactor `mutect2_pon.nf`**

Replace the full process with:

```groovy
/*
mutect2_pon.nf module

This module performs the initial GATK Mutect2 variant calling step
for creating a Panel of Normals (PON) from normal samples only.

Recommended # of normal samples: >= 40.

GATK Version: 4.2.0.0
*/

process MUTECT2_PON {
    tag "${sample_id}"
    label 'lowCpu'
    label 'medMem'
    label 'extraLongTime'

    input:
    tuple val(sample_id), path(normal_bam), path(normal_bai)
    path ref_fasta
    path ref_fasta_index

    output:
    path("*vcf*")

    script:
    """
    gatk Mutect2 \\
        -R ${ref_fasta} \\
        -I $normal_bam \\
        --max-mnp-distance 0 \\
        -O "${sample_id}.vcf.gz"
    """
}
```

- [ ] **Step 2: Refactor `genomics_db_import.nf` with tar output**

Replace the full process with:

```groovy
/*
genomics_db_import.nf module

This module creates a local GenomicsDB from VCF files for efficient
querying for creation of a Panel of Normals (PON).

Recommended # of normal samples: >= 40.

GATK Version: 4.2.0.0
*/

process GENOMICS_DB_IMPORT {
    tag "${interval_list.name}"
    label 'lowCpu'
    label 'highMem'
    label 'medTime'

    input:
    path(all_vcfs)
    path ref_fasta
    path ref_fasta_index
    path interval_list

    output:
    path "pon_db.tar"

    script:
    def vcf_args = all_vcfs.collect { "-V ${it}" }.join(" ")

    """
    gatk GenomicsDBImport \\
    -R ${ref_fasta} \\
    -L ${interval_list} \\
    --genomicsdb-workspace-path pon_db \\
    $vcf_args

    tar -cf pon_db.tar pon_db/
    """
}
```

- [ ] **Step 3: Refactor `create_pon.nf` with tar input**

Replace the full process with:

```groovy
/*
create_pon.nf module

This module creates a somatic panel of normals for Mutect2 to filter
out technical artifacts and germline variants.

Recommended # of normal samples: >= 40.

GATK Version: 4.2.0.0
*/

process CREATE_PON {
    tag "${interval_list.name}"
    label 'lowCpu'
    label 'highMem'
    label 'medTime'

    input:
    path(pon_db_tar)
    path ref_fasta
    path ref_fasta_index
    path gnomad_vcf
    path gnomad_vcf_index
    path interval_list

    output:
    path "*pon*vcf.gz"
    path "*pon*vcf.gz.tbi"

    script:
    def output_prefix = interval_list.baseName

    """
    tar -xf ${pon_db_tar}

    gatk CreateSomaticPanelOfNormals \\
    -R ${ref_fasta} \\
    --germline-resource ${gnomad_vcf} \\
    -V "gendb://pon_db" \\
    -O "${output_prefix}.pon.vcf.gz"

    gatk IndexFeatureFile -I "${output_prefix}.pon.vcf.gz"
    """
}
```

- [ ] **Step 4: Commit**

```bash
git add nextflow_automation/mutation_calling/modules/mutect2_pon/mutect2_pon.nf \
        nextflow_automation/mutation_calling/modules/mutect2_pon/genomics_db_import.nf \
        nextflow_automation/mutation_calling/modules/mutect2_pon/create_pon.nf
git commit -m "refactor: parameterize reference files in PON processes, tar GenomicsDB output"
```

---

## Task 4: Refactor MuSE and VarScan2 processes to use parameterized references

**Files:**
- Modify: `nextflow_automation/mutation_calling/modules/muse/muse.nf`
- Modify: `nextflow_automation/mutation_calling/modules/varscan2/pileup.nf`
- Modify: `nextflow_automation/mutation_calling/modules/varscan2/merge_vcf.nf`

- [ ] **Step 1: Refactor `muse.nf`**

Replace the full process with:

```groovy
/*
muse.nf module

This module channels in metadata from the metadata sheet performs mutation calling
on the reads using the MuSE variant caller for only paired samples.

MuSE Version: v1.0rc
*/

process MUSE {
    tag "${sample_id}"
    label 'lowCpu'
    label 'lowMem'
    label 'extraLongTime'

    input:
    tuple val(sample_id), val(tumor_id), path(tumor_bam), path(tumor_bai), path(tumor_sbi), val(normal_id), path(normal_bam, stageAs: "normal.bam"), path(normal_bai, stageAs: "normal.bai")
    path ref_fasta
    path ref_fasta_index
    path muse_dbsnp

    output:
    tuple val(sample_id), val(tumor_id), val(normal_id), path("${sample_id}.MuSE.sump.vcf")

    script:
    """
    # run MuSE variant caller
    # Step 1: MuSE call - unfiltered variant calling via comparison between normal/tumour bam
    MuSE call \
    -f ${ref_fasta} \
    -O "${sample_id}" \
    $tumor_bam \
    $normal_bam

    # Step 2: MuSE sump - processes / filters variants
    MuSE sump -D ${muse_dbsnp} \
    -E \
    -I "${sample_id}.MuSE.txt" \
    -O "${sample_id}.MuSE.sump.vcf"
    """
}
```

- [ ] **Step 2: Refactor `pileup.nf`**

Replace the full process with:

```groovy
/*
pileup.nf module

This module takes temporary SAM files and converts them to temporary BAM files
using SAMTools version 1.10.
*/
process PILEUP {
    tag "${sample_id}"
    label 'lowCpu'
    label 'lowMem'
    label 'extraLongTime'

    input:
    tuple val(sample_id), val(tumor_id), path(tumor_bam), path(tumor_bai), path(tumor_sbi), val(normal_id), path(normal_bam, stageAs: "normal.bam"), path(normal_bai, stageAs: "normal.bai")
    path ref_fasta
    path ref_fasta_index

    output:
    tuple val(sample_id), val(tumor_id), val(normal_id), path("${sample_id}.pileup")

    script:
    """
    # create pileup text file
    samtools mpileup -B \
    -f ${ref_fasta} \
    -q 1 \
    -o ${sample_id}.pileup \
    $normal_bam $tumor_bam
    """
}
```

- [ ] **Step 3: Refactor `merge_vcf.nf`**

Replace the full process with:

```groovy
/*
merge_vcf.nf module

This module merges the high confidence somatic VCF files from VarScan2,
compresses the files, and indexes them.

GATK Version: 4.2.0.0
*/

process MERGE_VCFS {
    tag "${sample_id}"
    label 'medCpu'
    label 'lowMem'
    label 'shortTime'

    input:
    tuple val(sample_id), val(tumor_id), val(normal_id), path(snp_vcf), path(indel_vcf)
    path ref_dict

    output:
    tuple val(sample_id), val(tumor_id), val(normal_id), path("${sample_id}.varscan2.vcf")

    script:
    """
    # merge high confidence snp and indel vcf files
    gatk MergeVcfs \
    -I $snp_vcf \
    -I $indel_vcf \
    -O "${sample_id}.varscan2.vcf.gz" \
    -D ${ref_dict}

    gunzip "${sample_id}.varscan2.vcf.gz"
    """
}
```

- [ ] **Step 4: Commit**

```bash
git add nextflow_automation/mutation_calling/modules/muse/muse.nf \
        nextflow_automation/mutation_calling/modules/varscan2/pileup.nf \
        nextflow_automation/mutation_calling/modules/varscan2/merge_vcf.nf
git commit -m "refactor: parameterize reference files in MuSE and VarScan2 processes"
```

---

## Task 5: Refactor shared annotation processes to use parameterized references

**Files:**
- Modify: `nextflow_automation/mutation_calling/modules/shared/select_variants.nf`
- Modify: `nextflow_automation/mutation_calling/modules/shared/vep.nf`
- Modify: `nextflow_automation/mutation_calling/modules/shared/create_maf.nf`
- Modify: `nextflow_automation/mutation_calling/modules/shared/keep_nonsynonymous.nf`
- Modify: `nextflow_automation/mutation_calling/modules/shared/oncokb.nf`

- [ ] **Step 1: Refactor `select_variants.nf`**

Add `path ref_fasta` and `path ref_fasta_index` inputs. Replace the `input:` block:

```groovy
    input:
    tuple val(sample_id), val(tumor_id), val(normal_id), path(compressed_vcf), path(index_file)
    path ref_fasta
    path ref_fasta_index
```

No script changes needed — `SelectVariants` in the current script doesn't reference `/references/` for its `-R` flag (it doesn't use one). No changes needed to the script block.

**Wait — re-checking the script:** The current `select_variants.nf` script does NOT use `-R` or any `/references/` path. It only uses `-V`, `-O`, `--exclude-filtered`, and `-L` flags. So this process does **not** need reference file inputs. Skip this step.

- [ ] **Step 2: Refactor `vep.nf` — upgrade to VEP 115 with external cache**

Replace the full process with:

```groovy
/*
vep.nf module

This module inputs the selected variant vcf files and annotates them for biological
effects, phenotype association, allele frequency reporting, and deleteriousness predictions using VEP.

Ensembl VEP Version: 115.
*/

process VEP {
    tag "${sample_id}"
    publishDir "${params.output_dir}/mutation_calls/mutect2/vep_annotated_vcfs", mode: 'copy', pattern: "*mutect2*vep.vcf*"
    publishDir "${params.output_dir}/mutation_calls/MuSE/vep_annotated_vcfs", mode: 'copy', pattern: "*MuSE*vep.vcf*"
    publishDir "${params.output_dir}/mutation_calls/varscan2/vep_annotated_vcfs", mode: 'copy', pattern: "*varscan2*vep.vcf*"
    label 'medCpu'
    label 'medMem'
    label 'medTime'

    input:
    tuple val(sample_id), val(tumor_id), val(normal_id), path(selected_vcf), path(index_file)
    path ref_fasta
    path ref_fasta_index
    path vep_cache

    output:
    tuple val(sample_id), path("*vep.vcf")

    script:
    """
    # save base name (no file paths) for file name manipulation based on variant caller
    BASE_NAME=\$(basename "${selected_vcf}")

    # replace file name parts based on variant caller
    OUTPUT_NAME=\${BASE_NAME/pass/vep}

    # annotate via VEP
    vep \
    --vcf \
    --input_file $selected_vcf \
    --output_file "\${OUTPUT_NAME%.gz}" \
    --everything \
    --species homo_sapiens \
    --no_stats \
    --fork ${task.cpus} \
    --cache \
    --offline \
    --fasta ${ref_fasta} \
    --dir_cache ${vep_cache} \
    --cache_version 115
    """
}
```

- [ ] **Step 3: Refactor `create_maf.nf`**

Add `path ref_fasta` input. Replace the `input:` block:

```groovy
    input:
    tuple val(sample_id), path(vcf)
    path ref_fasta
```

Replace the two `--ref-fasta /references/Homo_sapiens_assembly38.fasta` references in the script with `--ref-fasta ${ref_fasta}`. Specifically, replace line 45:

```groovy
              --ref-fasta ${ref_fasta} \
```

And replace line 58:

```groovy
              --ref-fasta ${ref_fasta} \
```

- [ ] **Step 4: Refactor `keep_nonsynonymous.nf`**

Add `path nonsynonymous_list` input. Replace the `input:` block:

```groovy
    input:
    tuple val(sample_id), path(maf_file)
    path nonsynonymous_list
```

Replace the grep line (line 40) in the script — change `/references/nonsynonymous.txt` to the staged input:

```groovy
      /references/nonsynonymous.txt $maf_file > "\$OUTPUT_NAME"
```
becomes:
```groovy
      ${nonsynonymous_list} $maf_file > "\$OUTPUT_NAME"
```

- [ ] **Step 5: Refactor `oncokb.nf` — dual-mode secret handling**

Replace the full process with:

```groovy
/*
oncokb.nf

This module provides clinically relevant annotations to the variant calling MAF files
using Oncokb.

Oncokb Version: 3.0.0.
*/

process ONCOKB {
    tag "${sample_id}"
    publishDir "${params.output_dir}/mutation_calls/mutect2/oncokb_annotation", mode: 'copy', pattern: "*mutect2*vep.nonsynonymous*"
    publishDir "${params.output_dir}/mutation_calls/MuSE/oncokb_annotation", mode: 'copy', pattern: "*MuSE*vep.nonsynonymous*"
    publishDir "${params.output_dir}/mutation_calls/varscan2/oncokb_annotation", mode: 'copy', pattern: "*varscan2*vep.nonsynonymous*"
    label 'lowCpu'
    label 'lowMem'
    label 'medTime'

    input:
    tuple val(sample_id), path(nonsyno_maf)

    output:
    tuple val(sample_id), path("*vep.nonsynonymous.oncokb.maf")

    script:
    def get_key = params.use_secrets_manager
        ? "ONCOKB_API_KEY=\$(aws secretsmanager get-secret-value --secret-id ${params.oncokb_secret_name} --query SecretString --output text)"
        : "ONCOKB_API_KEY=${params.oncokb_api_key}"

    """
    # retrieve OncoKB API key
    ${get_key}

    # save the base name to change parameters based on variant caller
    BASE_NAME=\$(basename "${nonsyno_maf}")

    if [[ "\$BASE_NAME" == *"mutect2.tumorOnly"* ]]; then
        OUTPUT_NAME="${sample_id}.mutect2.tumorOnly.vep.nonsynonymous.oncokb.maf"
    elif [[ "\$BASE_NAME" == *"mutect2.paired"* ]]; then
        OUTPUT_NAME="${sample_id}.mutect2.paired.vep.nonsynonymous.oncokb.maf"
    elif [[ "\$BASE_NAME" == *"MuSE"* ]]; then
        OUTPUT_NAME="${sample_id}.MuSE.vep.nonsynonymous.oncokb.maf"
    elif [[ "\$BASE_NAME" == *"varscan2"* ]]; then
        OUTPUT_NAME="${sample_id}.varscan2.vep.nonsynonymous.oncokb.maf"
    fi

    # annotate via oncokb
    python /app/MafAnnotator.py \
    -i $nonsyno_maf \
    -o \$OUTPUT_NAME \
    -r GRCh38 \
    -b "\$ONCOKB_API_KEY" \
    -t BRAIN
    """
}
```

- [ ] **Step 6: Commit**

```bash
git add nextflow_automation/mutation_calling/modules/shared/vep.nf \
        nextflow_automation/mutation_calling/modules/shared/create_maf.nf \
        nextflow_automation/mutation_calling/modules/shared/keep_nonsynonymous.nf \
        nextflow_automation/mutation_calling/modules/shared/oncokb.nf
git commit -m "refactor: parameterize reference files in shared annotation processes, upgrade VEP to v115"
```

---

## Task 6: Update main workflow to stage references and pass to processes

**Files:**
- Modify: `nextflow_automation/mutation_calling/mutation_calling.nf`

- [ ] **Step 1: Update `MUTATION_CALLING` workflow**

After the `parameter_validation()` call (line 103) and before the channel setup, add reference file staging:

```groovy
    // stage reference files from params
    ref_fasta           = file(params.ref_fasta)
    ref_fasta_index     = file(params.ref_fasta_index)
    ref_dict            = file(params.ref_dict)
    gnomad_vcf          = file(params.gnomad_vcf)
    gnomad_vcf_index    = file(params.gnomad_vcf_index)
    contamination_vcf   = file(params.contamination_vcf)
    contamination_vcf_index = file(params.contamination_vcf_index)
    muse_dbsnp          = file(params.muse_dbsnp)
    interval_list       = file(params.interval_list)
    nonsynonymous_list  = file(params.nonsynonymous_list)
    vep_cache           = file(params.vep_cache)
```

Then update all process calls (replacing lines 138-187):

```groovy
    // run Mutect2 steps defined by GATK best practices
    mutect2_calls = MUTECT2_CALL(bams, ref_fasta, ref_fasta_index, gnomad_vcf, gnomad_vcf_index, interval_list)
    pileup_summaries = GET_PILEUP_SUMMARIES(bams, ref_fasta, ref_fasta_index, contamination_vcf, contamination_vcf_index, interval_list)
    contamination_data = CALCULATE_CONTAMINATION(pileup_summaries)
    orientation_models = LEARN_READ_ORIENTATION(mutect2_calls)

    // join contamination and orientation data for filtering
    filter_input = orientation_models
        .join(contamination_data, by: [0, 1, 2])
        .map { sample_id, tumor_id, normal_id, unfiltered_vcf, m2_stats, orientation_model, contamination_table, segments_table ->
            tuple(sample_id, tumor_id, normal_id, unfiltered_vcf, m2_stats, orientation_model, contamination_table, segments_table)
        }

    // filter Mutect2 calls
    mutect2_vcfs = FILTER_MUTECT_CALLS(filter_input, ref_fasta, ref_fasta_index)

    // run MuSE variant caller
    muse_vcfs = MUSE(samples.paired, ref_fasta, ref_fasta_index, muse_dbsnp)

    // run VarScan2 variant caller
    pileups = PILEUP(samples.paired, ref_fasta, ref_fasta_index)
    varscan2_raw_vcfs = VARSCAN2(pileups)

    // merge the varscan2 vcfs
    varscan2_vcfs = MERGE_VCFS(varscan2_raw_vcfs, ref_dict)

    // concatenate all the data channels for vcfs
    filtered_vcfs = mutect2_vcfs.concat(muse_vcfs).concat(varscan2_vcfs)

    // compress and index the vcfs
    compressed_vcfs = INDEX(filtered_vcfs)

    // select for passing variants via gatk SelectVariants
    selected_vcfs = SELECT_VARIANTS(compressed_vcfs)

    // annotate for biological effects via VEP
    vep_annotated_vcfs = VEP(selected_vcfs, ref_fasta, ref_fasta_index, vep_cache)

    // change the column names in the vcf for standardization
    reheadered_vcfs = REHEADER(vep_annotated_vcfs)

    // generate MAF files
    maf_files = CREATE_MAF(reheadered_vcfs, ref_fasta)

    // filter out synonymous mutations
    nonsynonymous_mutations = KEEP_NONSYNONYMOUS(maf_files, nonsynonymous_list)

    // rename and reformat the files
    renamed_files = RENAME_HG38(nonsynonymous_mutations)

    // oncokb annotation for clinical relevance
    ONCOKB(renamed_files)
```

- [ ] **Step 2: Update `CREATE_M2_PON` workflow**

After the `parameter_validation()` call (line 197), add reference staging:

```groovy
    // stage reference files from params
    ref_fasta           = file(params.ref_fasta)
    ref_fasta_index     = file(params.ref_fasta_index)
    gnomad_vcf          = file(params.gnomad_vcf)
    gnomad_vcf_index    = file(params.gnomad_vcf_index)
    interval_list       = file(params.interval_list)
```

Update the process calls (replacing lines 217-226):

```groovy
    // main workflow
    normal_vcfs = MUTECT2_PON(normal_bams, ref_fasta, ref_fasta_index)

    // collect vcfs and pass to genomics_db_import
    normal_vcfs
        .collect()
        .set { all_vcfs }

    genomics_db = GENOMICS_DB_IMPORT(all_vcfs, ref_fasta, ref_fasta_index, interval_list)

    CREATE_PON(genomics_db, ref_fasta, ref_fasta_index, gnomad_vcf, gnomad_vcf_index, interval_list)
```

- [ ] **Step 3: Verify syntax**

Run: `cd nextflow_automation/mutation_calling && nextflow run mutation_calling.nf -entry MUTATION_CALLING --help`

Expected: Help message prints without syntax errors.

- [ ] **Step 4: Commit**

```bash
git add nextflow_automation/mutation_calling/mutation_calling.nf
git commit -m "refactor: wire parameterized reference files through main workflow"
```

---

## Task 7: Update test config with reference params

**Files:**
- Modify: `nextflow_automation/tests/shared-test.config`

- [ ] **Step 1: Add reference params to test config**

Add the following in the `params` block (after line 15, before the closing `}`):

```groovy
params {
    ref_dir = "${projectDir}/test-data/references"
    test_mode = true
    cpus = 1

    // test reference file paths
    ref_fasta = "${projectDir}/test-data/references/hg38_chr22.fasta"
    ref_fasta_index = "${projectDir}/test-data/references/hg38_chr22.fasta.fai"
    ref_dict = "${projectDir}/test-data/references/hg38_chr22.dict"
    gnomad_vcf = "${projectDir}/test-data/references/gnomAD_chr22.vcf.gz"
    gnomad_vcf_index = "${projectDir}/test-data/references/gnomAD_chr22.vcf.gz.tbi"
    contamination_vcf = "${projectDir}/test-data/references/gnomAD_chr22.vcf.gz"
    contamination_vcf_index = "${projectDir}/test-data/references/gnomAD_chr22.vcf.gz.tbi"
    muse_dbsnp = "${projectDir}/test-data/references/common_all_20180418.vcf.gz"
    interval_list = "${projectDir}/test-data/references/genome_intervals.hg38_chr22.bed"
    nonsynonymous_list = "${projectDir}/test-data/references/nonsynonymous.txt"
    vep_cache = "/opt/vep/.vep"

    // OncoKB test settings
    use_secrets_manager = false
    oncokb_api_key = "test-key"
    oncokb_secret_name = "oncokb-api-key"
}
```

Note: `vep_cache` still points to `/opt/vep/.vep` for tests since the test VEP container has the cache baked in. For production HealthOmics runs, the omics config will override this with an S3 path.

- [ ] **Step 2: Run existing Mutect2 tests to verify nothing is broken**

Run: `cd nextflow_automation && nf-test test tests/mutation_calling/modules/mutect2/*.nf.test`

Expected: All existing tests pass.

- [ ] **Step 3: Commit**

```bash
git add nextflow_automation/tests/shared-test.config
git commit -m "feat: add parameterized reference paths to test config"
```

---

## Task 8: Create `conf/omics.config` for HealthOmics overrides

**Files:**
- Create: `nextflow_automation/mutation_calling/conf/omics.config`

- [ ] **Step 1: Create the HealthOmics config file**

Create `nextflow_automation/mutation_calling/conf/omics.config`:

```groovy
/*
========================================================================================
    AWS HealthOmics Configuration
========================================================================================
    Loaded conditionally when $AWS_WORKFLOW_RUN is set.
    Overrides container images (ECR), publishDir, resource settings,
    and reference file paths for S3.
========================================================================================
*/

// -- Reference files from S3 (override these via --params-file or input JSON) --
params {
    // S3 reference paths — set these per-run or via parameter template
    ref_fasta               = null  // e.g., "s3://bucket/references/Homo_sapiens_assembly38.fasta"
    ref_fasta_index         = null  // e.g., "s3://bucket/references/Homo_sapiens_assembly38.fasta.fai"
    ref_dict                = null  // e.g., "s3://bucket/references/Homo_sapiens_assembly38.dict"
    gnomad_vcf              = null  // e.g., "s3://bucket/references/af-only-gnomad.hg38.vcf.gz"
    gnomad_vcf_index        = null  // e.g., "s3://bucket/references/af-only-gnomad.hg38.vcf.gz.tbi"
    contamination_vcf       = null  // e.g., "s3://bucket/references/small_exac_common_3.hg38.vcf.gz"
    contamination_vcf_index = null  // e.g., "s3://bucket/references/small_exac_common_3.hg38.vcf.gz.tbi"
    muse_dbsnp              = null  // e.g., "s3://bucket/references/common_all_20180418.vcf.gz"
    nonsynonymous_list      = null  // e.g., "s3://bucket/references/nonsynonymous.txt"
    vep_cache               = null  // e.g., "s3://bucket/vep-cache/homo_sapiens_merged/115_GRCh38/"
    interval_list           = null  // e.g., "s3://bucket/references/interval_list.bed"

    // Secrets Manager for OncoKB
    use_secrets_manager = true
    oncokb_secret_name  = "oncokb-api-key"

    // Output directory for HealthOmics
    publish_dir = "/mnt/workflow/pubdir"
}

// -- Process overrides --
process {
    // Remove local-only directives
    containerOptions = ''

    // -- ECR container images --
    // Replace <ACCOUNT_ID> and <REGION> with your AWS account and region
    withName: 'MUTECT2_CALL|GET_PILEUP_SUMMARIES|CALCULATE_CONTAMINATION|LEARN_READ_ORIENTATION|FILTER_MUTECT_CALLS|MERGE_VCFS|SELECT_VARIANTS' {
        container = '<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/gatk:4.2.0.0'
    }
    withName: 'MUTECT2_PON|GENOMICS_DB_IMPORT|CREATE_PON' {
        container = '<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/gatk:4.2.0.0'
    }
    withName: 'PILEUP|INDEX' {
        container = '<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/samtools:1.10'
    }
    withName: MUSE {
        container = '<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/muse:1.0.rc'
    }
    withName: VARSCAN2 {
        container = '<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/varscan2:latest'
    }
    withName: VEP {
        container = '<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/vep:115.0'
    }
    withName: REHEADER {
        container = '<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/bcftools:1.10.2'
    }
    withName: CREATE_MAF {
        container = '<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/vcf2maf:1.6.19'
    }
    withName: 'KEEP_NONSYNONYMOUS|RENAME_HG38' {
        container = '<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/ubuntu:20.04'
    }
    withName: ONCOKB {
        container = '<ACCOUNT_ID>.dkr.ecr.<REGION>.amazonaws.com/oncokb:3.0.0-awscli'
    }
}

// -- Disable local Docker options --
docker {
    runOptions = ''
}
```

- [ ] **Step 2: Commit**

```bash
git add nextflow_automation/mutation_calling/conf/omics.config
git commit -m "feat: add HealthOmics-specific config with ECR containers and S3 reference params"
```

---

## Task 9: Create OncoKB Dockerfile with awscli

**Files:**
- Create: `nextflow_automation/containerization/Dockerfile.oncokb-awscli`

- [ ] **Step 1: Create the Dockerfile**

Create `nextflow_automation/containerization/Dockerfile.oncokb-awscli`:

```dockerfile
FROM e10m/oncokb:3.0.0

# Install AWS CLI for Secrets Manager access on HealthOmics
RUN pip install --no-cache-dir awscli
```

- [ ] **Step 2: Build and verify**

Run: `docker build -f nextflow_automation/containerization/Dockerfile.oncokb-awscli -t e10m/oncokb:3.0.0-awscli .`

Expected: Build completes successfully.

Run: `docker run --rm e10m/oncokb:3.0.0-awscli aws --version`

Expected: AWS CLI version prints.

- [ ] **Step 3: Commit**

```bash
git add nextflow_automation/containerization/Dockerfile.oncokb-awscli
git commit -m "feat: add OncoKB Dockerfile with awscli for HealthOmics Secrets Manager"
```

---

## Task 10: Create ECR push script

**Files:**
- Create: `nextflow_automation/scripts/ecr_push.sh`

- [ ] **Step 1: Create the ECR push script**

Create `nextflow_automation/scripts/ecr_push.sh`:

```bash
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

# Define images: local_image -> ecr_repo:tag
declare -A IMAGES=(
    ["broadinstitute/gatk:4.2.0.0"]="gatk:4.2.0.0"
    ["quay.io/biocontainers/samtools:1.10--h9402c20_1"]="samtools:1.10"
    ["quay.io/biocontainers/muse:1.0.rc--1"]="muse:1.0.rc"
    ["e10m/varscan2:latest"]="varscan2:latest"
    ["ensemblorg/ensembl-vep:release_115.0"]="vep:115.0"
    ["e10m/vcf2maf:1.6.19"]="vcf2maf:1.6.19"
    ["e10m/oncokb:3.0.0-awscli"]="oncokb:3.0.0-awscli"
    ["staphb/bcftools:1.10.2"]="bcftools:1.10.2"
    ["ubuntu:20.04"]="ubuntu:20.04"
)

for LOCAL_IMAGE in "${!IMAGES[@]}"; do
    ECR_TAG="${IMAGES[$LOCAL_IMAGE]}"
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
```

- [ ] **Step 2: Make executable**

Run: `chmod +x nextflow_automation/scripts/ecr_push.sh`

- [ ] **Step 3: Commit**

```bash
git add nextflow_automation/scripts/ecr_push.sh
git commit -m "feat: add ECR push script for HealthOmics container images"
```

---

## Task 11: Create workflow packaging script

**Files:**
- Create: `nextflow_automation/scripts/package_omics.sh`

- [ ] **Step 1: Create the packaging script**

Create `nextflow_automation/scripts/package_omics.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Package Mutation Calling Workflow for AWS HealthOmics
# Usage: ./package_omics.sh [output_filename]
# Creates a ZIP archive ready for HealthOmics workflow upload.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MC_DIR="${SCRIPT_DIR}/../mutation_calling"
OUTPUT="${1:-mutation_calling_omics.zip}"

# Resolve absolute path for output
OUTPUT="$(cd "$(dirname "$OUTPUT")" && pwd)/$(basename "$OUTPUT")"

cd "${MC_DIR}"

echo "Packaging mutation calling workflow for HealthOmics..."

zip -r "${OUTPUT}" \
    mutation_calling.nf \
    nextflow.config \
    conf/omics.config \
    modules/ \
    -x "*.test" -x "*__pycache__*" -x "*.pyc"

echo "Package created: ${OUTPUT}"
echo "Size: $(du -h "${OUTPUT}" | cut -f1)"
echo ""
echo "Upload to HealthOmics via:"
echo "  aws omics create-workflow --name WESley-mutation-calling --definition-zip fileb://${OUTPUT} --engine NEXTFLOW"
```

- [ ] **Step 2: Make executable**

Run: `chmod +x nextflow_automation/scripts/package_omics.sh`

- [ ] **Step 3: Commit**

```bash
git add nextflow_automation/scripts/package_omics.sh
git commit -m "feat: add packaging script for HealthOmics workflow upload"
```

---

## Task 12: Run full test suite and verify

**Files:** None (verification only)

- [ ] **Step 1: Run all mutation calling tests**

Run: `cd nextflow_automation && nf-test test tests/mutation_calling/modules/mutect2/*.nf.test`

Expected: All existing Mutect2 tests pass. If any tests fail, investigate and fix — the ref param changes may require test fixture updates.

- [ ] **Step 2: Verify config parses cleanly**

Run: `cd nextflow_automation/mutation_calling && nextflow config .`

Expected: Config prints without errors, shows all `params.ref_*` defaults.

- [ ] **Step 3: Verify help message works**

Run: `cd nextflow_automation/mutation_calling && nextflow run mutation_calling.nf -entry MUTATION_CALLING --help`

Expected: Help message prints and exits cleanly.

- [ ] **Step 4: Verify packaging script**

Run: `nextflow_automation/scripts/package_omics.sh /tmp/test_package.zip`

Expected: ZIP file created containing all workflow files.

Run: `unzip -l /tmp/test_package.zip`

Expected: Lists `mutation_calling.nf`, `nextflow.config`, `conf/omics.config`, and all `modules/**/*.nf` files.

- [ ] **Step 5: Clean up and final commit**

```bash
rm -f /tmp/test_package.zip
```

If any fixes were needed during verification, commit them:

```bash
git add -A
git commit -m "fix: address test failures from HealthOmics refactoring"
```
