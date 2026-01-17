# Kinnex IsoSeq Pipeline - Usage Guide

## Overview

This Nextflow pipeline processes PacBio Kinnex/MAS-Seq data through the complete IsoSeq workflow:

1. **Segmentation** - Split concatenated reads using `skera split`
2. **Demultiplexing** - Primer removal and barcode demultiplexing using `lima`
3. **IsoSeq Processing** - Refine, cluster, align, and collapse isoforms
4. **Classification** - Isoform classification and reporting using `pigeon`

## Quick Start

```bash
nextflow run main.nf \
    -profile conda,slurm \
    --input samplesheet.tsv \
    --mas8_primers /path/to/mas8_primers.fasta \
    --isoseq_primers /path/to/IsoSeq_v2_primers_12.fasta \
    --conda_env /path/to/conda/envs/scKinnex \
    --outdir results
```

## Input Requirements

### Samplesheet (TSV)

The pipeline requires a **tab-separated** samplesheet with **no header** and the following columns:

| Column | Description |
|--------|-------------|
| 1. `POOL_NAME` | Unique identifier for the pool |
| 2. `HIFI_BAM_LOCATION` | Path to HiFi BAM file |
| 3. `LIMA_CSV_LOCATION` | Path to lima biosample CSV file |

Example `samplesheet.tsv`:

```
Pool1 /data/pool1.hifi_reads.bam /data/pool1_lima.csv
Pool2 /data/pool2.hifi_reads.bam /data/pool2_lima.csv
```

### Lima CSV (Biosample file)

Each pool needs a lima CSV file (comma-separated **with header**) mapping barcodes to sample names. This file is used by lima's `--biosample-csv` flag:

| Column | Description |
|--------|-------------|
| `Barcode` | Barcode identifier (e.g., `bc1001--bc1001`) |
| `Bio Sample` | Sample name |

Example `lima.csv`:

```csv
Barcode,Bio Sample
bc1001--bc1001,SampleA
bc1002--bc1002,SampleB
bc1003--bc1003,SampleC
```

## Parameters

### Required Parameters

| Parameter | Description |
|-----------|-------------|
| `--input` | Path to samplesheet TSV |
| `--mas8_primers` | Path to MAS8 primers FASTA (for segmentation) |
| `--isoseq_primers` | Path to IsoSeq primers FASTA |
| `--conda_env` | Path to existing conda environment |

### Reference Files

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--genome` | `GRCh38` | Genome key for preset references |
| `--ref_genome` | - | Override: path to reference genome FASTA |
| `--ref_annotation` | - | Override: path to annotation GTF |

### Output Options

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--outdir` | `./results` | Output directory |
| `--publish_dir_mode` | `copy` | How to publish files (`copy`, `symlink`, `link`) |

### Workflow Control

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--skip_segmentation` | `false` | Skip segmentation (if BAMs already segmented) |
| `--skip_pigeon` | `false` | Stop after isoseq collapse |

### Tool-Specific Options

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--skera_extra_args` | `''` | Extra arguments for skera split |
| `--lima_extra_args` | `'--isoseq --peek-guess'` | Extra arguments for lima |
| `--isoseq_refine_extra_args` | `''` | Extra arguments for isoseq refine |
| `--isoseq_cluster_extra_args` | `''` | Extra arguments for isoseq cluster2 |
| `--pbmm2_preset` | `'ISOSEQ'` | pbmm2 alignment preset |
| `--pbmm2_extra_args` | `'--sort'` | Extra arguments for pbmm2 |
| `--isoseq_collapse_extra_args` | `'--do-not-collapse-extra-5exons'` | Extra arguments for isoseq collapse |
| `--pigeon_classify_extra_args` | `''` | Extra arguments for pigeon classify |
| `--pigeon_filter_extra_args` | `''` | Extra arguments for pigeon filter |
| `--pigeon_report_extra_args` | `''` | Extra arguments for pigeon report |

### Resource Limits

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--max_cpus` | `48` | Maximum CPUs per process |
| `--max_memory` | `'180.GB'` | Maximum memory per process |
| `--max_time` | `'72.h'` | Maximum time per process |

### Environment Options

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--conda_env` | - | Path to existing conda environment |
| `--tmpdir` | - | Custom TMPDIR path |

## Profiles

### Execution Profiles

| Profile | Description |
|---------|-------------|
| `standard` | Local execution |
| `slurm` | SLURM cluster execution |
| `conda` | Use conda environment |
| `singularity` | Use Singularity containers |
| `docker` | Use Docker containers |
| `test` | Minimal resources for testing |

### Usage Examples

```bash
# Local execution with conda
nextflow run main.nf -profile conda --input samplesheet.tsv ...

# SLURM cluster with conda
nextflow run main.nf -profile slurm,conda --input samplesheet.tsv ...

# With custom work directory
nextflow run main.nf -profile slurm,conda -w /scratch/user/nf_work --input samplesheet.tsv ...

# With custom TMPDIR
nextflow run main.nf -profile slurm,conda --tmpdir /scratch/user/tmp --input samplesheet.tsv ...

# Skip segmentation (already segmented BAMs)
nextflow run main.nf -profile slurm,conda --skip_segmentation --input samplesheet.tsv ...

# Stop after isoseq (no pigeon)
nextflow run main.nf -profile slurm,conda --skip_pigeon --input samplesheet.tsv ...
```

## Output Structure

```
results/
├── segmentation/
│   └── {pool}/
│       └── {pool}.segmented.bam
├── lima/
│   └── {pool}/
│       ├── {pool}.lima.{barcode}.bam
│       ├── {pool}.lima.summary
│       └── {pool}.lima.counts
├── isoseq/
│   └── {sample}/
│       ├── refine/
│       │   └── {sample}.flnc.bam
│       ├── cluster/
│       │   └── {sample}.clustered.bam
│       ├── mapped/
│       │   ├── {sample}.mapped.bam
│       │   └── {sample}.mapped.bam.bai
│       └── collapse/
│           ├── {sample}.collapsed.gff
│           └── {sample}.collapsed.flnc_count.txt
├── pigeon/
│   └── {sample}/
│       ├── {sample}_classification.txt
│       ├── {sample}_classification.filtered_lite_classification.txt
│       ├── {sample}_junctions.txt
│       └── {sample}.report.json
└── pipeline_info/
    ├── execution_timeline.html
    ├── execution_report.html
    ├── execution_trace.txt
    └── pipeline_dag.svg
```

## Troubleshooting

### Common Issues

1. **Missing conda environment**: Ensure `--conda_env` points to a valid conda environment with all required tools (skera, lima, isoseq, pbmm2, pigeon).

2. **Reference files not found**: Check that `--ref_genome` and `--ref_annotation` paths are correct, or that the `--genome` key exists in `conf/genomes.config`.

3. **SLURM job failures**: Check the `.nextflow.log` file and individual job logs in the work directory.

4. **Memory errors**: Increase `--max_memory` or adjust process-specific resources in `conf/modules.config`.

### Resume Failed Runs

```bash
nextflow run main.nf -resume ...
```

## Configuration Files

- `nextflow.config` - Main configuration
- `conf/base.config` - Default resource allocations
- `conf/genomes.config` - Reference genome paths
- `conf/modules.config` - Process-specific settings
- `conf/slurm.config` - SLURM executor settings
