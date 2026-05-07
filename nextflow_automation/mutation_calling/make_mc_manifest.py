"""
make_mc_manifest.py module

Generates a JSON manifest of tumor/normal BAM pairs for the WESley mutation calling pipeline.
Supports two backends selectable via --platform:
  - local: scans a BAM directory on the local filesystem
  - omics: queries an AWS HealthOmics Sequence Store via boto3
    - NOTE: Requires AWS credentials (env vars, ~/.aws/credentials, or IAM execution role)
    - Tumor/normal classification and pairing are derived entirely from HealthOmics ReadSet
      metadata (sampleId, subjectId) — no external metadata sheet required.

Output format (manifest.json):
    {
      "samples": [
        {
          "sample_id":  "GBX1406",
          "tumor_id":   "GBX1406",
          "tumor_bam":  "s3://omics-bucket/store/rs-001/source1.bam",
          "tumor_bai":  "s3://omics-bucket/store/rs-001/source1.bam.bai",
          "tumor_sbi":  null,
          "normal_id":  "PT406.BLD",
          "normal_bam": "s3://omics-bucket/store/rs-002/source1.bam",
          "normal_bai": "s3://omics-bucket/store/rs-002/source1.bam.bai"
        }
      ]
    }

Missing optional fields (tumor_bai, tumor_sbi, normal_id, normal_bam, normal_bai) are null.

Python version: 3.10+
Polars version: 1.34.0
"""

import os
import glob
import re
import argparse
import json
import polars as pl


def find_normal_info(sample_id: str, metadata_subset: pl.DataFrame, normals_df: pl.DataFrame, bam_dir: str) -> dict:
    """Look up normal sample information for a given tumor sample."""
    metadata_row = metadata_subset.filter(pl.col("Short ID") == sample_id)

    if metadata_row.is_empty():
        return {
            "Tumor_ID": "NO_FILE",
            "Normal_ID": "NO_FILE",
            "Normal_BAM": "NO_FILE",
            "Normal_BAI": "NO_FILE"
        }

    tumor_id = metadata_row.get_column("Short ID").item()
    has_normal = metadata_row.get_column("DOES PT HAVE NRM?").item()

    if has_normal != "Y":
        return {
            "Tumor_ID": tumor_id,
            "Normal_ID": "NO_FILE",
            "Normal_BAM": "NO_FILE",
            "Normal_BAI": "NO_FILE"
        }

    # Find matching normal
    cell_line = metadata_row.get_column("Line").item()
    matching_normals = normals_df.filter(pl.col("Line") == cell_line)

    if matching_normals.is_empty():
        return {
            "Tumor_ID": tumor_id,
            "Normal_ID": "NO_FILE",
            "Normal_BAM": "NO_FILE",
            "Normal_BAI": "NO_FILE"
        }
    elif matching_normals.height == 1:
        # Get normal IDs
        normal_id = matching_normals.get_column("Short ID").item()
        normal_seq_id = matching_normals.get_column("WES ID").item()

        # Find BAM and BAI files
        bam_files = (glob.glob(f"{bam_dir}/normals/{normal_id}*.bam") or
                    glob.glob(f"{bam_dir}/normals/{normal_seq_id}*.bam"))
        bai_files = (glob.glob(f"{bam_dir}/normals/{normal_id}*.bai") or
                    glob.glob(f"{bam_dir}/normals/{normal_seq_id}*.bai"))

        return {
            "Tumor_ID": tumor_id,
            "Normal_ID": normal_id,
            "Normal_BAM": bam_files[0] if bam_files else "NO_FILE",
            "Normal_BAI": bai_files[0] if bai_files else "NO_FILE"
        }
    else:
        normal_bam = None
        normal_id = None
        normal_seq_id = None
        for row in matching_normals.iter_rows(named=True):
            matches = (glob.glob(f"{bam_dir}/normals/*{row['Line']}*.bam"))
            if matches:
                normal_bam = matches[0]
                normal_id = row["Short ID"]
                normal_seq_id = row["WES ID"]
                break

        bai_files = (glob.glob(f"{bam_dir}/normals/{normal_id}*.bai") or
                     glob.glob(f"{bam_dir}/normals/{normal_seq_id}*.bai")) if normal_id else []

        return {
            "Tumor_ID": tumor_id,
            "Normal_ID": normal_id if normal_id else "NO_FILE",
            "Normal_BAM": normal_bam if normal_bam else "NO_FILE",
            "Normal_BAI": bai_files[0] if bai_files else "NO_FILE"
        }
    
def lookup_shortid(tcgb_id: str, metadata_subset: pl.DataFrame) -> str:
    """Look up short ID given the TCGB ID for a given sample."""
    metadata_row = metadata_subset.filter(pl.col("WES ID") == tcgb_id)
    short_id = metadata_row.get_column("Short ID").item()
    return short_id

def build_manifest_local(bam_dir: str, metadata_sheet: str) -> list[dict]:
    """Scan a local BAM directory and return a list of sample dicts.

    Returns dicts with keys: sample_id, tumor_id, tumor_bam, tumor_bai,
    tumor_sbi, normal_id, normal_bam, normal_bai.
    Missing optional fields are None (not 'NO_FILE').
    """
    metadata_df = pl.read_excel(metadata_sheet)
    metadata_subset = metadata_df.select(["WES ID", "Short ID", "Sample Type", "Line", "DOES PT HAVE NRM?"])
    normals_df = metadata_subset.filter(pl.col("Sample Type") == "NRM")

    files = glob.glob(f"{bam_dir}/*.bam")
    samples = []

    for file in files:
        bam_file = os.path.basename(file)
        path = os.path.dirname(file)

        # Find index files — None when absent
        bai_files = glob.glob(f"{bam_dir}/{bam_file}*bai")
        bai_file = bai_files[0] if bai_files else None
        sbi_files = glob.glob(f"{bam_dir}/{bam_file}*sbi")
        sbi_file = sbi_files[0] if sbi_files else None

        # Extract sample ID from BAM filename (TCGB or short ID pattern)
        tcgb_match = re.search(r"^\d+\w*-\d+", bam_file)
        short_match = re.search(r"\w+\d+", bam_file)
        original_id = (tcgb_match.group(0) if tcgb_match
                       else short_match.group(0) if short_match
                       else None)
        if not original_id:
            continue

        short_id = lookup_shortid(original_id, metadata_subset) if tcgb_match else original_id

        normal_info = find_normal_info(short_id, metadata_subset, normals_df, bam_dir)

        samples.append({
            "sample_id": original_id,
            "tumor_id": short_id,
            "tumor_bam": f"{path}/{bam_file}",
            "tumor_bai": bai_file,
            "tumor_sbi": sbi_file,
            "normal_id":  None if normal_info["Normal_ID"]  == "NO_FILE" else normal_info["Normal_ID"],
            "normal_bam": None if normal_info["Normal_BAM"] == "NO_FILE" else normal_info["Normal_BAM"],
            "normal_bai": None if normal_info["Normal_BAI"] == "NO_FILE" else normal_info["Normal_BAI"],
        })

    return samples

def build_manifest_omics(store_id: str, region: str) -> list[dict]:
    """Query a HealthOmics Sequence Store and return a list of sample dicts.

    Tumor/normal classification uses a regex on sampleId (BLD, NRM, CD45 → normal).
    Tumor/normal pairing uses subjectId as the cell-line key.
    No external metadata sheet is required.

    boto3 credential chain is used automatically:
      1. AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY env vars
      2. ~/.aws/credentials (from `aws configure` or SSO)
      3. IAM execution role (automatic inside HealthOmics workflow runs)
    """
    import boto3

    # connect to HealthOmics client, add readset metadata into list
    omics = boto3.client("omics", region_name=region)
    paginator = omics.get_paginator("list_read_sets")
    all_readsets = []
    for page in paginator.paginate(sequenceStoreId=store_id):
        all_readsets.extend(page["readSets"])

    tumors = []
    normals = {}  # subjectId → {sample_id, bam_uri, bai_uri}

    # parse metadata from readset JSONs
    for rs in all_readsets:
        meta = omics.get_read_set_metadata(id=rs["id"], sequenceStoreId=store_id)
        sample_id  = meta.get("sampleId")
        subject_id = meta.get("subjectId")
        files      = meta.get("files", {})
        bam_uri    = files.get("source1", {}).get("s3Access", {}).get("s3Uri")
        bai_uri    = files.get("index",   {}).get("s3Access", {}).get("s3Uri")

        # classify — normal if sampleId contains BLD, NRM, or CD45
        if re.search(r"BLD|NRM|CD45|PBMC", sample_id or "", re.IGNORECASE):
            normals[subject_id] = {"sample_id": sample_id, "bam_uri": bam_uri, "bai_uri": bai_uri}
        else:
            tumors.append({"sample_id": sample_id, "subject_id": subject_id, "bam_uri": bam_uri, "bai_uri": bai_uri})

    # match each tumor to a normal sharing the same subjectId
    samples = []
    for tumor in tumors:
        normal = normals.get(tumor["subject_id"])
        samples.append({
            "sample_id": tumor["sample_id"],
            "tumor_id":  tumor["sample_id"],
            "tumor_bam": tumor["bam_uri"],
            "tumor_bai": tumor["bai_uri"],
            "tumor_sbi": None,  # HealthOmics Sequence Store does not produce SBI files
            "normal_id":  normal["sample_id"] if normal else None,
            "normal_bam": normal["bam_uri"]    if normal else None,
            "normal_bai": normal["bai_uri"]    if normal else None,
        })

    return samples


def main():
    parser = argparse.ArgumentParser(
        description="Manifest generator for the WESley mutation calling pipeline"
    )
    parser.add_argument(
        "--platform", choices=["local", "omics"], required=True,
        help="Execution platform: 'local' scans a BAM directory; 'omics' queries a HealthOmics Sequence Store"
    )
    parser.add_argument(
        "-d", "--bam_dir", type=str,
        help="(local only) Directory containing analysis-ready BAM files"
    )
    parser.add_argument(
        "-m", "--metadata", type=str,
        help="(local only) Path to sequencing Excel metadata sheet"
    )
    parser.add_argument(
        "-o", "--output", type=str, required=True,
        help="Output path for manifest JSON (e.g. manifest.json)"
    )
    # HealthOmics-only args — validated at runtime if --platform omics
    parser.add_argument("--store_id", type=str, help="(omics only) HealthOmics Sequence Store ID")
    parser.add_argument("--region",   type=str, help="(omics only) AWS region of the Sequence Store")

    args = parser.parse_args()

    if args.platform == "local":
        if not args.bam_dir:
            parser.error("--bam_dir is required when --platform local")
        if not args.metadata:
            parser.error("--metadata is required when --platform local")
        samples = build_manifest_local(args.bam_dir, args.metadata)
    else:
        if not args.store_id or not args.region:
            parser.error("--store_id and --region are required when --platform omics")
        samples = build_manifest_omics(args.store_id, args.region)

    manifest = {"samples": samples}
    with open(args.output, "w") as f:
        json.dump(manifest, f, indent=2)

    print(f"Manifest written to: {args.output} ({len(samples)} samples)")


if __name__ == "__main__":
    main()
