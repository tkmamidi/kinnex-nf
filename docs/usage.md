# Kinnex IsoSeq Pipeline - Usage Guide

## Overview

This Nextflow pipeline processes PacBio Kinnex/MAS-Seq data through the complete IsoSeq workflow:

1. **Segmentation** - Split concatenated reads using `skera split`
2. **Demultiplexing** - Primer removal and barcode demultiplexing using `lima`
3. **IsoSeq Processing** - Refine, cluster, align, and collapse isoforms
4. **Classification** - Isoform classification and reporting using `pigeon`
5. **Variant Calling** - SNP/indel calling from IsoSeq reads using `Clair3-RNA`
6. **Fusion Gene Detection** - Per-sample fusion breakpoint calling using `pbfusion`
7. **Isoform Profiling** - Per-sample isoform profiles using `isocall` for downstream joint-calling

## Quick Start

```bash
nextflow run main.nf \
    -profile conda,slurm \
    --input samplesheet.tsv \
    --mas8_primers /path/to/mas8_primers.fasta \
    --isoseq_primers /path/to/IsoSeq_v2_primers_12.fasta \
    --pbfusion_binary /path/to/pbfusion \
    --isocall_binary /path/to/isocall \
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

### Reference Files

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--genome` | `GRCh38` | Genome key for preset references |
| `--ref_genome` | - | Override: path to reference genome FASTA |
| `--ref_annotation` | - | Override: path to annotation GTF |
| `--pbfusion_binary` | - | Path to pre-downloaded pbfusion binary (falls back to `pbfusion` on `PATH`) |
| `--isocall_binary` | - | Path to pre-downloaded isocall binary (required unless `--skip_isocall`) |

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
| `--skip_variant_calling` | `false` | Skip Clair3-RNA variant calling |
| `--skip_fusion_calling` | `false` | Skip pbfusion fusion gene detection |
| `--skip_isocall` | `false` | Skip isocall isoform profiling |

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
| `--clair3_rna_extra_args` | `''` | Extra arguments for Clair3-RNA |
| `--clair3_rna_platform` | `'hifi_mas_pbmm2'` | Clair3-RNA platform (see [models](https://github.com/HKU-BAL/Clair3-RNA)) |
| `--pbfusion_extra_args` | `'--min-coverage 5'` | Extra arguments for pbfusion discover |
| `--isocall_extra_args` | `''` | Extra arguments for isocall profile |

### Resource Limits

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--max_cpus` | `48` | Maximum CPUs per process |
| `--max_memory` | `'180.GB'` | Maximum memory per process |
| `--max_time` | `'72.h'` | Maximum time per process |

### Environment Options

| Parameter | Default | Description |
|-----------|---------|-------------|
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

# Skip variant calling only
nextflow run main.nf -profile slurm,conda --skip_variant_calling --input samplesheet.tsv ...

# Skip fusion gene detection only
nextflow run main.nf -profile slurm,conda --skip_fusion_calling --input samplesheet.tsv ...

# Skip isocall profiling only
nextflow run main.nf -profile slurm,conda --skip_isocall --input samplesheet.tsv ...
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

## Troubleshooting

### Common Issues

1. **Missing conda environment**: With `-profile conda`, Nextflow builds the environment from `assets/scKinnex_simple.yml` (containing skera, lima, isoseq, pbmm2, pigeon). Ensure conda is available and the YAML resolves.

2. **Reference files not found**: Check that `--ref_genome` and `--ref_annotation` paths are correct, or that the `--genome` key exists in `conf/genomes.config`.

3. **SLURM job failures**: Check the `.nextflow.log` file and individual job logs in the work directory.

4. **Memory errors**: Increase `--max_memory` or adjust process-specific resources in `conf/modules.config`.

### Resume Failed Runs

```bash
nextflow run main.nf -resume ...
```

## Downstream Isocall Joint-Calling

The pipeline generates per-sample isocall profiles. To perform joint isoform calling across selected samples, run isocall merge and call manually:

```bash
# 1. Merge selected sample profiles
isocall merge \
    --profiles results/isocall/profiles/SampleA/SampleA.profile.gz \
                results/isocall/profiles/SampleB/SampleB.profile.gz \
    --output merged.gz

# 2. Joint-call isoforms across merged samples
isocall call \
    --merged-profile merged.gz \
    --known-isoforms results/isocall/ref.isoforms.gz \
    --reference /path/to/ref.fasta \
    --output-prefix joint_calls
```

This two-step approach lets you choose which samples to include in joint-calling (e.g., group by condition, tissue type, or experiment).

## Setting Up Clair3-RNA

Clair3-RNA runs via a Singularity/Docker container (`hkubal/clair3-rna:latest`). On SLURM clusters with Singularity, the container is pulled automatically when you use the `singularity` profile. Ensure Singularity is available on your compute nodes.

Available platforms for `--clair3_rna_platform`:

| Platform | Description |
|----------|-------------|
| `hifi_mas_pbmm2` | Kinnex/MAS-Seq aligned with pbmm2 (default) |
| `hifi_mas_minimap2` | Kinnex/MAS-Seq aligned with minimap2 |
| `hifi_sequel2_pbmm2` | Sequel II aligned with pbmm2 |
| `hifi_sequel2_minimap2` | Sequel II aligned with minimap2 |

## Setting Up pbfusion

pbfusion detects fusion genes from the aligned (mapped) IsoSeq reads and requires the reference annotation GTF (`--ref_annotation` or a valid `--genome` key). Install it one of two ways ([project README](https://github.com/PacificBiosciences/pbfusion)):

```bash
# Option A: bioconda (recommended by the pbfusion project)
conda install -c bioconda pbfusion

# Option B: pre-compiled binary from the GitHub releases page
#   https://github.com/PacificBiosciences/pbfusion/releases
#   Download the binary asset for the latest release, then:
chmod +x pbfusion
```

Then provide the binary path via `--pbfusion_binary /path/to/pbfusion`. If omitted, the pipeline falls back to `pbfusion` on the `PATH` (e.g. when installed into the conda environment). Per-sample fusion breakpoints are written to `fusion_calling/{sample}/{sample}.breakpoints.groups.bed`. Use `--skip_fusion_calling` to disable this step.

## Setting Up Isocall

Download the isocall binary from [GitHub releases](https://github.com/PacificBiosciences/isocall/releases):

```bash
wget https://github.com/PacificBiosciences/isocall/releases/download/0.15.0/isocall-v0.15.0.gz
gunzip isocall-v0.15.0.gz
chmod +x isocall-v0.15.0
```

Then provide the path via `--isocall_binary /path/to/isocall-v0.15.0`.

## Configuration Files

- `nextflow.config` - Main configuration
- `conf/base.config` - Default resource allocations
- `conf/genomes.config` - Reference genome paths
- `conf/modules.config` - Process-specific settings
- `conf/slurm.config` - SLURM executor settings
