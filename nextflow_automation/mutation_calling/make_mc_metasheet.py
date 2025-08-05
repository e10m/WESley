"""
make_mc_metasheet.py module

This python script creates a metadata sheet which matches the tumor BAM files and their indices
to their respective matching normals (if available).

NOTE: The metadata sheet being read from is subject to change, please change column names accordingly!

The format follows as below:
    eg:
    Sample_ID   Tumor_ID   Tumor_BAM   Tumor_BAI   Tumor_SBI   Normal_ID    Normal_BAM
    23-028  GBX1406 23-028.BQSR.bam 23-028.BQSR.bam.bai 23-028.BQSR.bam.sbi PT406.BLD   23B-036.recalibration.sort.bam
"""

import os
import glob
import re
import argparse
import pandas as pd

# initialize argparser and the arguments
parser = argparse.ArgumentParser(description="Simple metadata sheet generator for the mutation calling portion of the WES pipeline")

parser.add_argument('-d','--bam_dir', type=str, required=True,
                    help="Directory where the FASTQ data is")

parser.add_argument('-b', '--batch_number', type=int, required=True,
                    help="Batch number for the WES data being analyzed")

parser.add_argument('-o', '--output_dir', default='./', type=str, required=True,
                    help='Where to output your file')

parser.add_argument('-m', '--metadata', type=str, required=True,
                    help='Path to where the sequencing metadata sheet is')

args = parser.parse_args()

# input home directory
bam_dir = args.bam_dir
batch_number = args.batch_number
output_dir = args.output_dir
metadata = args.metadata

# find all BAM files
files = glob.glob(f"{bam_dir}/*.bam")

# initialize output file name
output_file = f"{output_dir}/batch{batch_number}_mc_metasheet.tsv"

# initialize list to store the data
data = []

### NOTE: The metadata sheet being read from is subject to change, please change column names accordingly!
# read in the 'Sequencing Metadata MAIN' .xls file
metadata_df = pd.read_excel(metadata)

### NOTE: The metadata sheet being read from is subject to change, please change column names accordingly!
# subset metadata df
metadata_subset = metadata_df[["WES ID", "Short ID", "Sample Type", "Line", "DOES PT HAVE NRM?"]]
normals_df = metadata_subset[metadata_subset['Sample Type'] == 'NRM']

# iterate through bam files and create the data frame
for file in files:
    bam_file = os.path.basename(file)
    path = os.path.dirname(file)

    # get the sample name
    sample_name = re.search(r"^\d+\w*-\d+", bam_file)

    # skip cases where normal BAMs not named in
    # canonical TCGB naming convention
    if sample_name is None:
        continue

    # ternary statement to see if bai / sbi found, otherwise just placeholder string
    bai_files = glob.glob(f"{bam_dir}/{sample_name.group(0)}*bai")
    bai_file = bai_files[0] if bai_files else "NO_FILE"
    sbi_files = glob.glob(f"{bam_dir}/{sample_name.group(0)}*sbi")
    sbi_file = sbi_files[0] if sbi_files else "NO_FILE"

    # append the rows to the data list
    data.append([
        sample_name.group(0),
        f"{path}/{bam_file}",
        bai_file,
        sbi_file
    ])

# convert data list to pandas data frame
df = pd.DataFrame(data, columns=["Sample_ID", "Tumor_BAM", "Tumor_BAI", "Tumor_SBI"])

# insert 'Tumor_ID', 'Normal_BAM' column to df
df.insert(1, 'Tumor_ID', '')
df.insert(5, 'Normal_ID', '')
df.insert(6, 'Normal_BAM', '')
df.insert(7, 'Normal_BAI', '')

# iterate through the df and update it based on 'Sequencing Metadata Main' values
for index, row in df.iterrows():
    sample_id = row["Sample_ID"]

    metadata_row = metadata_subset[metadata_subset['WES ID'] == sample_id]
    
    # Set Tumor_ID
    df.at[index, 'Tumor_ID'] = metadata_row['Short ID'].iloc[0]
    
    # Check if patient has matching normal
    if metadata_row["DOES PT HAVE NRM?"].iloc[0] == "Y":
        # store cell line
        cell_line = metadata_row["Line"].iloc[0]
        matching_normals = normals_df[normals_df['Line'] == cell_line]
        
        # matching normal available
        if not matching_normals.empty:
            # store IDs
            normal_id = matching_normals['Short ID'].iloc[0]
            normal_seq_id = matching_normals['WES ID'].iloc[0]
            
            # find and store bam file
            bam_file = (glob.glob(f"{bam_dir}/normals/{normal_id}*.bam") or 
                       glob.glob(f"{bam_dir}/normals/{normal_seq_id}*.bam"))
            bai_file = (glob.glob(f"{bam_dir}/normals/{normal_id}*.bai") or 
                       glob.glob(f"{bam_dir}/normals/{normal_seq_id}*.bai"))
            
            # impute df with appropriate values
            df.at[index, 'Normal_ID'] = normal_id
            df.at[index, 'Normal_BAM'] = bam_file[0] if bam_file else "NO_FILE"
            df.at[index, 'Normal_BAI'] = bai_file[0] if bai_file else "NO_FILE"
        
        # tumor only; append false values
        else:
            df.at[index, 'Normal_ID'] = "NO_FILE"
            df.at[index, 'Normal_BAM'] = "NO_FILE"
            df.at[index, 'Normal_BAI'] = "NO_FILE"
    
    # tumor only; append false values
    else:
        df.at[index, 'Normal_ID'] = "NO_FILE"
        df.at[index, 'Normal_BAM'] = "NO_FILE"
        df.at[index, 'Normal_BAI'] = "NO_FILE"

# TODO: remove the normals marked as tumors from the metasheet
for index, row in df.iterrows():
    tumor_id = row["Tumor_ID"]
    if (tumor_id in row["Normal_BAM"]) or (tumor_id == row["Normal_ID"]):
        df = df.drop([index])

# write out file
df.to_csv(output_file, sep="\t", index=False)

print(f"Writing metadata sheet to: {output_file}")