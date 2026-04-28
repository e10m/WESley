"""
test_make_mc_manifest.py module

This python script tests 'make_mc_manifest.py' with a test dataset.

Python version: 3.10+
Polars version: 1.34.0
PyTest version: 7.4.4
"""
import json
import pytest
import polars as pl
import sys
from unittest.mock import patch
import tempfile
import os
from pathlib import Path
from nextflow_automation.mutation_calling.make_mc_manifest import (
    find_normal_info, lookup_shortid, build_manifest_local, main
)


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
    with patch('nextflow_automation.mutation_calling.make_mc_manifest.glob.glob') as mock_glob:
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


def test_build_manifest_local(sample_metadata):
    """build_manifest_local returns list of dicts with null for missing fields (not 'NO_FILE')."""
    with tempfile.TemporaryDirectory() as temp_root:
        bam_dir = os.path.join(temp_root, "bams")
        normals_dir = os.path.join(bam_dir, "normals")
        os.makedirs(bam_dir)
        os.makedirs(normals_dir)

        # Tumor samples
        Path(os.path.join(bam_dir, "23-028.BQSR.bam")).touch()
        Path(os.path.join(bam_dir, "23-028.BQSR.bam.bai")).touch()
        Path(os.path.join(bam_dir, "23-028.BQSR.bam.sbi")).touch()
        Path(os.path.join(bam_dir, "23-029.BQSR.bam")).touch()
        Path(os.path.join(bam_dir, "23-029.BQSR.bam.bai")).touch()

        # Normal sample
        Path(os.path.join(normals_dir, "PT406.BLD.bam")).touch()
        Path(os.path.join(normals_dir, "PT406.BLD.bam.bai")).touch()

        metadata_file = os.path.join(temp_root, "metadata.xlsx")
        sample_metadata.write_excel(metadata_file)

        result = build_manifest_local(bam_dir, metadata_file)

        assert isinstance(result, list)
        assert len(result) == 2

        # Paired sample
        s1 = next(s for s in result if s["tumor_id"] == "GBX1406")
        assert s1["sample_id"] == "23-028"
        assert s1["tumor_bam"].endswith("23-028.BQSR.bam")
        assert s1["tumor_bai"].endswith("23-028.BQSR.bam.bai")
        assert s1["tumor_sbi"].endswith("23-028.BQSR.bam.sbi")
        assert s1["normal_id"] == "PT406.BLD"
        assert s1["normal_bam"].endswith("normals/PT406.BLD.bam")
        assert s1["normal_bai"].endswith("normals/PT406.BLD.bam.bai")

        # Tumor-only: missing fields are None, not 'NO_FILE'
        s2 = next(s for s in result if s["tumor_id"] == "GBX1407")
        assert s2["sample_id"] == "23-029"
        assert s2["normal_id"] is None
        assert s2["normal_bam"] is None
        assert s2["normal_bai"] is None


def test_main(sample_metadata):
    """main() with --platform local writes valid JSON with params.samples schema."""
    with tempfile.TemporaryDirectory() as temp_root:
        bam_dir = os.path.join(temp_root, "bams")
        normals_dir = os.path.join(bam_dir, "normals")
        os.makedirs(bam_dir)
        os.makedirs(normals_dir)

        Path(os.path.join(bam_dir, "23-028.BQSR.bam")).touch()
        Path(os.path.join(bam_dir, "23-028.BQSR.bam.bai")).touch()
        Path(os.path.join(bam_dir, "23-028.BQSR.bam.sbi")).touch()
        Path(os.path.join(bam_dir, "23-029.BQSR.bam")).touch()
        Path(os.path.join(bam_dir, "23-029.BQSR.bam.bai")).touch()

        Path(os.path.join(normals_dir, "PT406.BLD.bam")).touch()
        Path(os.path.join(normals_dir, "PT406.BLD.bam.bai")).touch()

        metadata_file = os.path.join(temp_root, "metadata.xlsx")
        sample_metadata.write_excel(metadata_file)

        output_file = os.path.join(temp_root, "manifest.json")

        mock_args = [
            "make_mc_manifest.py",
            "--platform", "local",
            "--bam_dir", bam_dir,
            "--metadata", metadata_file,
            "--output", output_file,
        ]
        with patch.object(sys, "argv", mock_args):
            main()

        assert os.path.exists(output_file), "manifest.json was not created"
        with open(output_file) as f:
            data = json.load(f)

        assert "samples" in data
        assert len(data["samples"]) == 2

        s1 = next(s for s in data["samples"] if s["tumor_id"] == "GBX1406")
        assert s1["sample_id"] == "23-028"
        assert s1["tumor_bam"].endswith("23-028.BQSR.bam")
        assert s1["tumor_bai"].endswith("23-028.BQSR.bam.bai")
        assert s1["tumor_sbi"].endswith("23-028.BQSR.bam.sbi")
        assert s1["normal_id"] == "PT406.BLD"
        assert s1["normal_bam"].endswith("normals/PT406.BLD.bam")
        assert s1["normal_bai"].endswith("normals/PT406.BLD.bam.bai")

        # Tumor-only: null not 'NO_FILE'
        s2 = next(s for s in data["samples"] if s["tumor_id"] == "GBX1407")
        assert s2["normal_id"] is None
        assert s2["normal_bam"] is None
        assert s2["normal_bai"] is None
