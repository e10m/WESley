"""
make_metadata_sheet.py

Description:
    This script reads in a WES data metadata, parses the sample names, and generates a .tsv file 
    containing metadata regarding each sample. The output metadata sheet is then passed to the Nextflow
    pipeline for processing, mutation calling, and CNV calling.

    NOTE: The metadata sheet being read from is subject to change, please change column names accordingly!
    
    The format follows as below:
    eg:
        Sample_ID  Lane FASTQ_R1    FASTQ_R2    Platform    Sequencing_Center   Mouse_Flag
        23-028  L003    23-028_S1_L003_R1_001.fastq.gz  23-028_S1_L003_R2_001.fastq.gz  Illumina_NovaSeq6000    TCGB    False
"""

import os
import glob
import re
import argparse
import pandas as pd

# initialize argparser and the arguments
parser = argparse.ArgumentParser(description="Simple metadata sheet generator for WES pipeline")

parser.add_argument('-f','--fastq_directory', type=str, required=True,
                    help="Directory where the FASTQ data is")

parser.add_argument('-b', '--batch_number', type=int, required=True,
                    help="Batch number for the WES data being analyzed")

parser.add_argument('-p', '--platform', type=str, default='Illumina_NovaSeqXPlus', required=True,
                    help="Sequencing platform used to generate the WES data")

parser.add_argument('-s', '--sequencing_center', type=str, default='TCGB', required=True,
                    help='Sequencing Center where the WES data was generated')

parser.add_argument('-m', '--metadata', type=str, required=True,
                    help='Path to where the sequencing metadata sheet is')

parser.add_argument('-o', '--output_dir', default='./', type=str, required=True,
                    help='Where to output your file')

args = parser.parse_args()

# input home directory
fastq_dir = args.fastq_directory
batch_number = args.batch_number
platform = args.platform
seq_center = args.sequencing_center
metadata = args.metadata
output_dir = args.output_dir

# find all files ending with 'R1_001.fastq.gz'
files = glob.glob(f"{fastq_dir}/*R1_001.fastq.gz")

# initialize output file name
output_file = f"{output_dir}/batch{batch_number}_metadata.tsv"

# initialize list to store the data
data = []

# iterate through files, parse, save into Pandas dataframe
for file in files:
    r1_file = os.path.basename(file)
    r2_file = r1_file.replace("_R1_", "_R2_")
    lane = re.search(r"L\d+", r1_file)
    sample_name = re.search(r"^\d+\w*-\d+", r1_file)

    # append the rows to the data list
    data.append([
        sample_name.group(0),
        lane.group(0),
        r1_file,
        r2_file,
        platform,
        seq_center,
        False
    ])

# convert data list to pandas data frame
df = pd.DataFrame(data, columns=["Sample_ID", "Lane", "FASTQ_R1", "FASTQ_R2", "Platform", "Sequencing_Center", "Mouse_Flag"])

### NOTE: The metadata sheet being read from is subject to change, please change column names accordingly!
# read in the metadata
metadata_df = pd.read_excel(metadata)

### NOTE: The metadata sheet being read from is subject to change, please change column names accordingly!
# subset metadata df
metadata_subset = metadata_df[["WES ID", "Short ID"]]

# replace the indices with the TCGB ID names
metadata_subset = metadata_subset.set_index("WES ID")

# update Mouse_Flag for samples with ending with 'X' (eg: GBX, SDX, etc.)
for sample_id in df["Sample_ID"]:
    lab_name = metadata_subset.at[sample_id, "Short ID"]

    # search for whether samples have been in some sort of xenograft to mark for true for bbsplit
    has_x = re.search(r"XG?\d+\.*", lab_name)
    if has_x is None:
        df.loc[df["Sample_ID"] == sample_id, "Mouse_Flag"] = False
    else: 
        df.loc[df["Sample_ID"] == sample_id, "Mouse_Flag"] = True

# write out file
df.to_csv(output_file, sep="\t", index=False)

print(f"Writing metadata sheet to: {output_file}")