"""
make_mc_metasheet.py module

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
import polars as pl


def find_normal_info(sample_id: str, metadata_subset: pl.DataFrame, normals_df: pl.DataFrame, bam_dir: str) -> dict:
    """Look up normal sample information for a given tumor sample."""
    metadata_row = metadata_subset.filter(pl.col("WES ID") == sample_id)

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


def main():
    # initialize argparser and the arguments
    parser = argparse.ArgumentParser(description="Simple metadata sheet generator for the mutation calling portion of the WES pipeline")

    parser.add_argument('-d','--bam_dir', type=str, required=True,
                        help="Directory where the analysis ready BAM files are.")

    parser.add_argument('-b', '--batch_name', type=int, required=True,
                        help="Batch name for the WES data being analyzed.")

    parser.add_argument('-o', '--output_dir', default='./', type=str, required=True,
                        help='Directory to publish the output metadata tsv sheet.')

    parser.add_argument('-m', '--metadata', type=str, required=True,
                        help='Path to where the sequencing xls metadata sheet is')

    args = parser.parse_args()

    # input home directory
    bam_dir = args.bam_dir
    batch_name = args.batch_name
    output_dir = args.output_dir
    metadata = args.metadata

    # find all BAM files
    files = glob.glob(f"{bam_dir}/*.bam")

    # initialize output file name
    output_file = f"{output_dir}/{batch_name}_mc_metasheet.tsv"

    ### NOTE: The metadata sheet being read from is subject to change, please change column names accordingly!
    # read in the 'Sequencing Metadata MAIN' .xls file
    metadata_df = pl.read_excel(metadata)

    ### NOTE: The metadata sheet being read from is subject to change, please change column names accordingly!
    # subset metadata df
    metadata_subset = metadata_df.select(["WES ID", "Short ID", "Sample Type", "Line", "DOES PT HAVE NRM?"])
    normals_df = metadata_subset.filter(pl.col("Sample Type") == "NRM")

    # build data list from BAM files
    data = []
    for file in files:
        bam_file = os.path.basename(file)
        path = os.path.dirname(file)

        # get the sample name
        sample_name = re.search(r"^\d+\w*-\d+", bam_file)  # get TCGB ID

        # get short ID
        if sample_name is None:
            sample_name = re.search(r"\w+\d+", bam_file)

        if sample_name is None:
            continue

        sample_id = sample_name.group(0)

        # find BAI and SBI files
        bai_files = glob.glob(f"{bam_dir}/{sample_id}*bai")
        bai_file = bai_files[0] if bai_files else "NO_FILE"
        sbi_files = glob.glob(f"{bam_dir}/{sample_id}*sbi")
        sbi_file = sbi_files[0] if sbi_files else "NO_FILE"

        # look up normal information
        normal_info = find_normal_info(sample_id, metadata_subset, normals_df, bam_dir)

        # append the row data
        data.append({
            "Sample_ID": sample_id,
            "Tumor_ID": normal_info["Tumor_ID"],
            "Tumor_BAM": f"{path}/{bam_file}",
            "Tumor_BAI": bai_file,
            "Tumor_SBI": sbi_file,
            "Normal_ID": normal_info["Normal_ID"],
            "Normal_BAM": normal_info["Normal_BAM"],
            "Normal_BAI": normal_info["Normal_BAI"]
        })

    # convert data list to Polars DataFrame
    df = pl.DataFrame(data)

    # remove rows where the tumor is incorrectly marked as its own normal
    df = df.filter(
        ~(
            pl.col("Normal_BAM").str.contains(pl.col("Tumor_ID")) |
            (pl.col("Tumor_ID") == pl.col("Normal_ID"))
        )
    )

    # write out file
    df.write_csv(output_file, separator="\t")

    print(f"Writing metadata sheet to: {output_file}")


if __name__ == "__main__":
    main()