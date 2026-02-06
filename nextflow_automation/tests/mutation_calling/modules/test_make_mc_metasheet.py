"""
test_make_mc_metasheet.py module

This python script tests 'make_mc_metasheet.py' with a test dataset.

Python version: 3.10+
Polars version: 1.34.0
PyTest version: 7.4.4
"""
import pytest
import polars as pl
from unittest.mock import patch

from nextflow_automation.mutation_calling import find_normal_info, lookup_shortid


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


def test_main():
    """Test the main function of make_mc_metasheet.py."""
    # This is a placeholder for testing the main function, which would require
    # more extensive setup and teardown to handle file I/O and command-line arguments.
    pass