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
           │  (mapped BAM per sample, branches run in parallel)
           ├────────────────┬────────────────┐
           ▼                ▼                ▼
    ┌──────────────┐ ┌──────────────┐ ┌──────────────────────────┐
    │  CLAIR3-RNA  │ │   PBFUSION   │ │    ISOCALL SUBWORKFLOW   │
    │  (variant    │ │ (fusion gene │ │  ┌──────────┐ ┌────────┐ │
    │   calling)   │ │  detection)  │ │  │ PREP     │ │PROFILE │ │
    │ (per sample) │ │ (per sample) │ │  │(ref GTF) │ │(per    │ │
    └──────┬───────┘ └──────┬───────┘ │  └──────────┘ │sample) │ │
           │                │         │               └───┬────┘ │
           ▼                ▼         └───────────────────┼──────┘
    ┌──────────────┐ ┌──────────────┐                     ▼
    │  VCF files   │ │  Fusion BED  │        ┌──────────────────────┐
    │ (per sample) │ │ (breakpoints)│        │  Per-sample profiles │
    └──────────────┘ └──────────────┘        │  for downstream merge│
                                             │  & joint-call        │
                                             └──────────────────────┘
```

## Features

- **Modular design** - Skip segmentation, pigeon, variant calling, fusion calling, or isocall as needed
- **Multi-sample support** - Process multiple pools and samples in parallel
- **Flexible execution** - Run locally, on SLURM clusters, or in containers
- **Variant calling** - SNP/indel calling from IsoSeq reads using Clair3-RNA
- **Fusion gene detection** - Per-sample fusion breakpoint calling using pbfusion
- **Isoform profiling** - Per-sample isoform profiles via isocall for downstream joint-calling
- **Comprehensive outputs** - Isoform classifications, VCFs, QC reports, and execution metrics
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

### Additional Tools

- [Clair3-RNA](https://github.com/HKU-BAL/Clair3-RNA) - RNA variant caller (via Singularity/Docker container `hkubal/clair3-rna:latest`)
- [pbfusion](https://github.com/PacificBiosciences/pbfusion) - Fusion gene detection from aligned IsoSeq reads (pre-downloaded binary)
- [isocall](https://github.com/PacificBiosciences/isocall) - Joint isoform calling (pre-downloaded binary)

### Reference Files

- Reference genome FASTA (+ `.fai` index)
- Annotation GTF (+ `.pgi` pigeon index)
- MAS8 primers FASTA
- IsoSeq primers FASTA
- pbfusion binary (download from [GitHub releases](https://github.com/PacificBiosciences/pbfusion/releases))
- Isocall binary (download from [GitHub releases](https://github.com/PacificBiosciences/isocall/releases))

## Quick Start

```bash
# Basic run with SLURM and conda
nextflow run main.nf \
    -profile slurm,conda \
    --input samplesheet.tsv \
    --mas8_primers /path/to/mas8_primers.fasta \
    --isoseq_primers /path/to/IsoSeq_v2_primers_12.fasta \
    --pbfusion_binary /path/to/pbfusion \
    --isocall_binary /path/to/isocall \
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
| `--pbfusion_binary` | - | Path to pre-downloaded pbfusion binary |
| `--isocall_binary` | - | Path to pre-downloaded isocall binary |

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
| `--skip_variant_calling` | `false` | Skip Clair3-RNA variant calling |
| `--skip_fusion_calling` | `false` | Skip pbfusion fusion gene detection |
| `--skip_isocall` | `false` | Skip isocall isoform profiling |

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
├── variant_calling/
│   └── {sample}/
│       └── {sample}_clair3_rna/
│           ├── output.vcf.gz
│           └── output.vcf.gz.tbi
├── fusion_calling/
│   └── {sample}/
│       └── {sample}.breakpoints.groups.bed
├── isocall/
│   ├── ref.isoforms.gz
│   └── profiles/
│       └── {sample}/
│           └── {sample}.profile.gz
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

# Skip variant calling, fusion calling, and isocall
nextflow run main.nf \
    -profile slurm,conda \
    --skip_variant_calling \
    --skip_fusion_calling \
    --skip_isocall \
    --input samplesheet.tsv \
    ...
```

### Downstream Isocall Joint-Calling

After the pipeline produces per-sample profiles, you can run isocall merge and call on selected samples:

```bash
# Merge selected sample profiles
isocall merge \
    --profiles results/isocall/profiles/SampleA/SampleA.profile.gz \
                results/isocall/profiles/SampleB/SampleB.profile.gz \
    --output merged.gz

# Joint-call isoforms
isocall call \
    --merged-profile merged.gz \
    --known-isoforms results/isocall/ref.isoforms.gz \
    --reference /path/to/ref.fasta \
    --output-prefix joint_calls
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
- [pbfusion](https://github.com/PacificBiosciences/pbfusion)
- [Isocall](https://github.com/PacificBiosciences/isocall)

And from the community:
- [Clair3-RNA](https://github.com/HKU-BAL/Clair3-RNA)
