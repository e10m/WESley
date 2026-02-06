"""
test_make_mc_metasheet.py module

This python script tests 'make_mc_metasheet.py' with a test dataset.

Python version: 3.10+
Polars version: 1.34.0
PyTest version: 7.4.4
"""
import pytest
import polars as pl
import sys
from unittest.mock import patch
import tempfile
import os
from pathlib import Path
from nextflow_automation.mutation_calling import find_normal_info, lookup_shortid, main


@pytest.fixture
def sample_metadata():
    """Create a sample metadata DataFrame for testing within temporary directory."""

    data = {
        "WES ID": ["23-028", "23-029", "23-030", "22-001"],
        "Short ID": ["GBX1406", "GBX1407", "GBX1408", "PT406.BLD"],
        "Sample Type": ["GBX", "GBX", "GBX", "NRM"],
        "DOES PT HAVE NRM?": ["Y", "N", "N", "Y"],
        "Line": ["406", "407", "408", "406"]
    }
    df = pl.DataFrame(data)
    return df


@pytest.fixture
def temp_dir():
    """Create a temporary directory for testing."""
    with tempfile.TemporaryDirectory() as tmpdir:
        yield tmpdir
    

def test_find_normal_info(sample_metadata):
    """Test the find_normal_info function with sample metadata."""
    normal_df = sample_metadata.filter(pl.col("Sample Type") == "NRM")
    bam_dir = "/path/to/bams"

    # mock glob calls to return expected BAM and BAI files
    with patch('nextflow_automation.mutation_calling.make_mc_metasheet.glob.glob') as mock_glob:
        # configure mock return values - patterns must match what the function actually calls
        pattern_responses = {
            f"{bam_dir}/normals/PT406.BLD*.bam": [f"{bam_dir}/normals/PT406.BLD.bam"],
            f"{bam_dir}/normals/PT406.BLD*.bai": [f"{bam_dir}/normals/PT406.BLD.bam.bai"],
            f"{bam_dir}/normals/22-001*.bam": [],  # WES ID fallback pattern
            f"{bam_dir}/normals/22-001*.bai": []   # WES ID fallback pattern
        }

        mock_glob.side_effect = lambda pattern: pattern_responses.get(pattern, [])

        # test case with normal available
        result = find_normal_info(
            sample_id="GBX1406",
            metadata_subset=sample_metadata,
            normals_df=normal_df,
            bam_dir=bam_dir
        )

        assert result == {
            "Tumor_ID": "GBX1406",
            "Normal_ID": "PT406.BLD",
            "Normal_BAM": f"{bam_dir}/normals/PT406.BLD.bam",
            "Normal_BAI": f"{bam_dir}/normals/PT406.BLD.bam.bai"
        }

        # test case 1 with no normal available
        result_no_normal = find_normal_info(
            sample_id="GBX1407",
            metadata_subset=sample_metadata,
            normals_df=normal_df,
            bam_dir=bam_dir
        )

        assert result_no_normal == {
            "Tumor_ID": "GBX1407",
            "Normal_ID": "NO_FILE",
            "Normal_BAM": "NO_FILE",
            "Normal_BAI": "NO_FILE"
        }

        # test case 2 with no normal available
        result_no_normal = find_normal_info(
            sample_id="GBX1408",
            metadata_subset=sample_metadata,
            normals_df=normal_df,
            bam_dir=bam_dir
        )
    
        assert result_no_normal == {
            "Tumor_ID": "GBX1408",
            "Normal_ID": "NO_FILE",
            "Normal_BAM": "NO_FILE",
            "Normal_BAI": "NO_FILE"
        }


def test_lookup_shortid(sample_metadata):
    """Test the lookup_shortid function with sample metadata."""
    # test case with existing TCGB IDs
    for tcgb_id in sample_metadata.get_column("WES ID"):
        short_id = lookup_shortid(tcgb_id=tcgb_id, metadata_subset=sample_metadata)
        assert short_id in sample_metadata.get_column("Short ID").to_list()


def test_main(sample_metadata):
    """Integration test for main() function with real file I/O."""

    with tempfile.TemporaryDirectory() as temp_root:
        # Set up directory structure
        bam_dir = os.path.join(temp_root, "bams")
        output_dir = os.path.join(temp_root, "output")
        normals_dir = os.path.join(bam_dir, "normals")

        # Create directories
        os.makedirs(bam_dir)
        os.makedirs(output_dir)
        os.makedirs(normals_dir)

        # Create fake BAM files for tumor samples
        Path(os.path.join(bam_dir, "23-028.BQSR.bam")).touch()
        Path(os.path.join(bam_dir, "23-028.BQSR.bam.bai")).touch()
        Path(os.path.join(bam_dir, "23-028.BQSR.bam.sbi")).touch()

        Path(os.path.join(bam_dir, "23-029.BQSR.bam")).touch()
        Path(os.path.join(bam_dir, "23-029.BQSR.bam.bai")).touch()

        # Create fake BAM files for normal sample
        Path(os.path.join(normals_dir, "PT406.BLD.bam")).touch()
        Path(os.path.join(normals_dir, "PT406.BLD.bam.bai")).touch()

        # Write metadata to Excel file
        metadata_file = os.path.join(temp_root, "metadata.xlsx")
        sample_metadata.write_excel(metadata_file)

        # Mock sys.argv with command-line arguments
        mock_args = [
            'make_mc_metasheet.py',
            '--bam_dir', bam_dir,
            '--batch_name', 'test-batch',
            '--output_dir', output_dir,
            '--metadata', metadata_file
        ]

        # Call main() with mocked arguments
        with patch.object(sys, 'argv', mock_args):
            main()

        # Verify output file exists
        output_file = os.path.join(output_dir, 'test-batch_mc_metasheet.tsv')
        assert os.path.exists(output_file), "Output TSV file was not created"

        # Read and verify output structure
        result_df = pl.read_csv(output_file, separator="\t")
        expected_columns = [
            "Sample_ID", "Tumor_ID", "Tumor_BAM", "Tumor_BAI",
            "Tumor_SBI", "Normal_ID", "Normal_BAM", "Normal_BAI"
        ]
        assert list(result_df.columns) == expected_columns, f"Column mismatch. Got: {result_df.columns}"
        assert result_df.height == 2, f"Expected 2 rows, got {result_df.height}"

        # Verify specific content for Row 1: GBX1406 with normal
        row1 = result_df.filter(pl.col("Tumor_ID") == "GBX1406")
        assert row1.height == 1, "Expected exactly one row for GBX1406"

        assert row1["Sample_ID"][0] == "23-028"
        assert row1["Tumor_ID"][0] == "GBX1406"
        assert row1["Tumor_BAM"][0].endswith("23-028.BQSR.bam")
        assert row1["Tumor_BAI"][0].endswith("23-028.BQSR.bam.bai")
        assert row1["Tumor_SBI"][0].endswith("23-028.BQSR.bam.sbi")
        assert row1["Normal_ID"][0] == "PT406.BLD"
        assert row1["Normal_BAM"][0].endswith("normals/PT406.BLD.bam")
        assert row1["Normal_BAI"][0].endswith("normals/PT406.BLD.bam.bai")

        # Verify specific content for Row 2: GBX1407 without normal
        row2 = result_df.filter(pl.col("Tumor_ID") == "GBX1407")
        assert row2.height == 1, "Expected exactly one row for GBX1407"

        assert row2["Sample_ID"][0] == "23-029"
        assert row2["Tumor_ID"][0] == "GBX1407"
        assert row2["Tumor_BAM"][0].endswith("23-029.BQSR.bam")
        assert row2["Tumor_BAI"][0].endswith("23-029.BQSR.bam.bai")
        assert row2["Normal_ID"][0] == "NO_FILE"
        assert row2["Normal_BAM"][0] == "NO_FILE"
        assert row2["Normal_BAI"][0] == "NO_FILE"