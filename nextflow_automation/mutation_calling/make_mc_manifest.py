"""
make_mc_manifest.py module

This python script creates a metadata sheet which matches the tumor BAM files and their indices
to their respective matching normals (if available).

NOTE: The metadata sheet being read from is subject to change, please change column names accordingly!

The format follows as below:
    eg:
    Sample_ID   Tumor_ID   Tumor_BAM   Tumor_BAI   Tumor_SBI   Normal_ID    Normal_BAM
    23-028  GBX1406 23-028.BQSR.bam 23-028.BQSR.bam.bai 23-028.BQSR.bam.sbi PT406.BLD   23B-036.recalibration.sort.bam

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
            # Convert 'NO_FILE' sentinel to None for JSON schema
            "normal_id":  None if normal_info["Normal_ID"]  == "NO_FILE" else normal_info["Normal_ID"],
            "normal_bam": None if normal_info["Normal_BAM"] == "NO_FILE" else normal_info["Normal_BAM"],
            "normal_bai": None if normal_info["Normal_BAI"] == "NO_FILE" else normal_info["Normal_BAI"],
        })

    # Remove rows where the tumor is incorrectly marked as its own normal
    samples = [
        s for s in samples
        if not (s["normal_bam"] and s["tumor_id"] in s["normal_bam"])
        and s["tumor_id"] != s["normal_id"]
    ]

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
        "-m", "--metadata", type=str, required=True,
        help="Path to sequencing Excel metadata sheet"
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
        samples = build_manifest_local(args.bam_dir, args.metadata)
    else:
        if not args.store_id or not args.region:
            parser.error("--store_id and --region are required when --platform omics")
        samples = build_manifest_omics(args.store_id, args.region, args.metadata)

    manifest = {"samples": samples}
    with open(args.output, "w") as f:
        json.dump(manifest, f, indent=2)

    print(f"Manifest written to: {args.output} ({len(samples)} samples)")


if __name__ == "__main__":
    main()
