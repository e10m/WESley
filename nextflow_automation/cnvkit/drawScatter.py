import pandas as pd
import os
import glob
import re

# find the cns files, store in list
files = glob.glob("*.cns")

for cns_file in files:
    # get the base name
    base_name = os.path.basename(cns_file)

    # get sample id
    sample_id = re.search(r"\d+\w?-\d+", base_name).group(0)

    # initialize cnr file
    cnr_file = cns_file.replace("_noDrop_t0005.cns", ".BQSR.cnr")

    command = f"cnvkit.py scatter -s {cns_file} -g CDKN2A -o {sample_id}.CDKN2A.pdf --title {sample_id}_EGFR {cnr_file}"
    os.system(command)
