# kinnex-nf

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A523.04.0-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](https://img.shields.io/badge/run%20with-conda-3EB049?logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg)](https://sylabs.io/docs/)

A Nextflow pipeline for processing PacBio Kinnex/MAS-Seq data through the complete IsoSeq workflow.

## Overview

This pipeline processes PacBio Kinnex (MAS-Seq) long-read sequencing data for isoform-level transcriptome analysis. It takes HiFi reads as input and produces classified, filtered isoforms with comprehensive QC reports.

## Pipeline Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           KINNEX ISOSEQ PIPELINE                            │
└─────────────────────────────────────────────────────────────────────────────┘

    ┌──────────────┐
    │  HiFi BAMs   │
    │  (per pool)  │
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │ SKERA SPLIT  │  ← MAS8 primers
    │ (Segmentation)│
    └──────┬───────┘
           │
           ▼
    ┌──────────────┐
    │    LIMA      │  ← IsoSeq primers + Lima CSV (barcodes)
    │(Demultiplex) │
    └──────┬───────┘
           │
           ▼  (per sample)
    ┌──────────────────────────────────────────────────────┐
    │                   ISOSEQ SUBWORKFLOW                 │
    │  ┌────────────┐  ┌────────────┐  ┌────────────────┐  │
    │  │   REFINE   │→ │  CLUSTER   │→ │  PBMM2 ALIGN   │  │
    │  │(polyA trim)│  │ (cluster2) │  │ (to reference) │  │
    │  └────────────┘  └────────────┘  └───────┬────────┘  │
    │                                          │           │
    │                                          ▼           │
    │                                  ┌────────────────┐  │
    │                                  │    COLLAPSE    │  │
    │                                  │(unique isoforms)│  │
    │                                  └────────────────┘  │
    └──────────────────────────────────────────────────────┘
           │
           ▼
    ┌──────────────────────────────────────────────────────┐
    │                   PIGEON SUBWORKFLOW                 │
    │  ┌────────────┐  ┌────────────┐  ┌────────────────┐  │
    │  │  PREPARE   │→ │  CLASSIFY  │→ │    FILTER      │  │
    │  │ (sort GFF) │  │ (annotate) │  │ (quality ctrl) │  │
    │  └────────────┘  └────────────┘  └───────┬────────┘  │
    │                                          │           │
    │                                          ▼           │
    │                                  ┌────────────────┐  │
    │                                  │    REPORT      │  │
    │                                  │ (saturation)   │  │
    │                                  └────────────────┘  │
    └──────────────────────────────────────────────────────┘
           │
           ▼
    ┌──────────────┐
    │   RESULTS    │
    │ (per sample) │
    └──────────────┘
```

## Features

- **Modular design** - Skip segmentation or pigeon classification as needed
- **Multi-sample support** - Process multiple pools and samples in parallel
- **Flexible execution** - Run locally, on SLURM clusters, or in containers
- **Comprehensive outputs** - Isoform classifications, QC reports, and execution metrics
- **Resume capability** - Restart from any point using Nextflow's `-resume` feature

## Requirements

### Software Dependencies

- [Nextflow](https://www.nextflow.io/) (≥23.04.0)
- [Conda](https://docs.conda.io/en/latest/) / [Singularity](https://sylabs.io/docs/) / [Docker](https://www.docker.com/)

### PacBio Tools (via conda environment)

- `skera` - MAS-Seq read segmentation
- `lima` - Demultiplexing and primer removal
- `isoseq` - IsoSeq3 processing tools
- `pbmm2` - PacBio minimap2 wrapper
- `pigeon` - Isoform classification

### Reference Files

- Reference genome FASTA (+ `.fai` index)
- Annotation GTF (+ `.pgi` pigeon index)
- MAS8 primers FASTA
- IsoSeq primers FASTA

## Quick Start

```bash
# Basic run with SLURM and conda
nextflow run main.nf \
    -profile slurm,conda \
    --input samplesheet.tsv \
    --mas8_primers /path/to/mas8_primers.fasta \
    --isoseq_primers /path/to/IsoSeq_v2_primers_12.fasta \
    --outdir results

# Resume a failed run
nextflow run main.nf -resume ...
```

## Input Files

### Samplesheet (TSV)

A **tab-separated** file with **no header** containing:

| Column | Description |
|--------|-------------|
| `POOL_NAME` | Unique identifier for the sequencing pool |
| `HIFI_BAM_LOCATION` | Path to HiFi BAM file |
| `LIMA_CSV_LOCATION` | Path to lima biosample CSV file |

**Example:**
```
Pool1	/data/pool1.hifi_reads.bam	/data/pool1_barcodes.csv
Pool2	/data/pool2.hifi_reads.bam	/data/pool2_barcodes.csv
```

### Lima CSV (Biosample File)

A **comma-separated** file **with header** mapping barcodes to sample names:

```csv
Barcode,Bio Sample
bc1001--bc1001,SampleA
bc1002--bc1002,SampleB
bc1003--bc1003,SampleC
```

## Parameters

### Required

| Parameter | Description |
|-----------|-------------|
| `--input` | Path to samplesheet TSV |
| `--mas8_primers` | Path to MAS8 primers FASTA |
| `--isoseq_primers` | Path to IsoSeq primers FASTA |

### Reference Genome

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--genome` | `GRCh38` | Genome key (see `conf/genomes.config`) |
| `--ref_genome` | - | Override: custom reference FASTA path |
| `--ref_annotation` | - | Override: custom annotation GTF path |

### Output

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--outdir` | `./results` | Output directory |
| `--publish_dir_mode` | `copy` | File publishing mode (`copy`, `symlink`, `link`) |

### Workflow Control

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--skip_segmentation` | `false` | Skip skera split (if BAMs already segmented) |
| `--skip_pigeon` | `false` | Stop after isoseq collapse |

### Resource Limits

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--max_cpus` | `48` | Maximum CPUs per process |
| `--max_memory` | `180.GB` | Maximum memory per process |
| `--max_time` | `72.h` | Maximum time per process |

> See [docs/usage.md](docs/usage.md) for a complete list of parameters.

## Profiles

| Profile | Description |
|---------|-------------|
| `standard` | Local execution |
| `slurm` | SLURM cluster execution |
| `conda` | Use conda environment |
| `singularity` | Use Singularity containers |
| `docker` | Use Docker containers |
| `test` | Minimal resources for testing |

**Combine profiles as needed:**
```bash
nextflow run main.nf -profile slurm,conda ...
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
│       └── {pool}.lima.summary
├── isoseq/
│   └── {sample}/
│       ├── refine/
│       │   └── {sample}.flnc.bam
│       ├── cluster/
│       │   └── {sample}.clustered.bam
│       ├── mapped/
│       │   └── {sample}.mapped.bam
│       └── collapse/
│           ├── {sample}.collapsed.gff
│           └── {sample}.collapsed.flnc_count.txt
├── pigeon/
│   └── {sample}/
│       ├── {sample}_classification.txt
│       ├── {sample}_classification.filtered_lite_classification.txt
│       ├── {sample}_junctions.txt
│       └── {sample}.saturation.txt
└── pipeline_info/
    ├── execution_timeline.html
    ├── execution_report.html
    ├── execution_trace.txt
    └── pipeline_dag.svg
```

## Configuration Files

| File | Description |
|------|-------------|
| `nextflow.config` | Main configuration file |
| `conf/base.config` | Default resource allocations |
| `conf/genomes.config` | Reference genome paths |
| `conf/modules.config` | Process-specific settings |
| `conf/slurm.config` | SLURM executor configuration |

## Usage Examples

```bash
# Standard run on SLURM cluster
nextflow run main.nf \
    -profile slurm,conda \
    --input samplesheet.tsv \
    --mas8_primers mas8_primers.fasta \
    --isoseq_primers IsoSeq_v2_primers.fasta \
    --outdir results

# Custom reference genome
nextflow run main.nf \
    -profile slurm,conda \
    --input samplesheet.tsv \
    --ref_genome /path/to/custom.fasta \
    --ref_annotation /path/to/custom.gtf \
    ...

# Skip segmentation (pre-segmented BAMs)
nextflow run main.nf \
    -profile slurm,conda \
    --skip_segmentation \
    --input samplesheet.tsv \
    ...

# Custom work directory
nextflow run main.nf \
    -profile slurm,conda \
    -w /scratch/user/nf_work \
    --input samplesheet.tsv \
    ...
```

## Troubleshooting

### Common Issues

1. **Reference files not found**
   - Verify paths in `--ref_genome` and `--ref_annotation`
   - Check that index files (`.fai`, `.pgi`) exist

2. **SLURM job failures**
   - Check `.nextflow.log` for details
   - Inspect job logs in the `work/` directory

3. **Memory errors**
   - Increase `--max_memory` parameter
   - Adjust process-specific resources in `conf/modules.config`

4. **Missing tools**
   - Ensure conda environment contains all required PacBio tools
   - Check tool versions are compatible

### Resume Failed Runs

```bash
nextflow run main.nf -resume [other options...]
```

## Documentation

- [Usage Guide](docs/usage.md) - Detailed parameter descriptions and examples

## License

This project is licensed under the MIT License.

## Acknowledgements

This pipeline uses tools from [PacBio](https://www.pacb.com/):
- [Skera](https://github.com/PacificBiosciences/skera)
- [Lima](https://github.com/PacificBiosciences/barcoding)
- [IsoSeq](https://github.com/PacificBiosciences/IsoSeq)
- [pbmm2](https://github.com/PacificBiosciences/pbmm2)
- [Pigeon](https://github.com/PacificBiosciences/pigeon)
