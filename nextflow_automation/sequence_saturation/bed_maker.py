"""
bed_maker.py module

This Python script takes in a reference exon capture target sheet and parses it, generating
a BED file to use for additional descriptive statistics.
"""

import pandas as pd

df = pd.read_csv("/media/graeberlab/wdtwo/dmach/references/KAPA_HyperExome_hg38_capture_targets.reference.cnn", sep="\t")

# Filter out "Antitarget" rows
df_filtered = df[df["gene"] != "Antitarget"]

# Extract BED fields
bed = df_filtered[["chromosome", "start", "end"]]

bed.to_csv("exome_targets.bed", sep="\t", header=False, index=False)
