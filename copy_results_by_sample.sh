#!/usr/bin/env bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=4G
#SBATCH --time=4:00:00
#SBATCH --output=copy_results_%j.out
#SBATCH --error=copy_results_%j.err
#SBATCH --job-name=copy_results

# copy_results_by_sample.sh
#
# Reorganizes pipeline output from step-based layout into per-sample layout:
#   SOURCE/isoseq/SAMPLE/collapse/ -> DEST/SAMPLE/collapse/
#   SOURCE/isoseq/SAMPLE/mapped/   -> DEST/SAMPLE/mapped/
#   SOURCE/pigeon/SAMPLE/          -> DEST/SAMPLE/pigeon/
#
# Mapped BAMs/BAIs are also copied flat into BAM_DEST.
#
# Usage:
#   sbatch copy_results_by_sample.sh <source_results_dir>
#   # or directly:
#   ./copy_results_by_sample.sh <source_results_dir>
#
# Example:
#   sbatch copy_results_by_sample.sh pools_22_27_results

set -euo pipefail

#------------------------------------------------------------------------------
# CONFIGURATION - adjust paths here
#------------------------------------------------------------------------------
PROJECT_DIR="/cluster/home/tmamidi/tarun/kinnex_try/kinnex-nf"
DEST="/analysis/cloud_projects/research/bulkrna-kinnex-nf-results"
BAM_DEST="/analysis/cloud_projects/research/FL_Kinnex_mapped_flnc"
SOURCE="pools_22_27_results"  # <-- set this to the source directory relative to project dir or absolute path
#------------------------------------------------------------------------------

# Resolve source relative to project dir if not absolute
if [[ "$SOURCE" != /* ]]; then
    SOURCE="${PROJECT_DIR}/${SOURCE}"
fi

SOURCE="$(realpath "$SOURCE")"

ISOSEQ_DIR="${SOURCE}/isoseq"
PIGEON_DIR="${SOURCE}/pigeon"

if [[ ! -d "$ISOSEQ_DIR" ]]; then
    echo "ERROR: isoseq directory not found: $ISOSEQ_DIR"
    exit 1
fi

echo "Source      : $SOURCE"
echo "Dest        : $DEST"
echo "BAM flat dir: $BAM_DEST"
echo ""

mkdir -p "$DEST"
mkdir -p "$BAM_DEST"

# Collect all samples from the isoseq directory
mapfile -t SAMPLES < <(ls -1 "$ISOSEQ_DIR")

echo "Found ${#SAMPLES[@]} sample(s) in $ISOSEQ_DIR"
echo ""

for SAMPLE in "${SAMPLES[@]}"; do
    SAMPLE_ISOSEQ="${ISOSEQ_DIR}/${SAMPLE}"
    SAMPLE_PIGEON="${PIGEON_DIR}/${SAMPLE}"
    SAMPLE_DEST="${DEST}/${SAMPLE}"

    echo "Processing: $SAMPLE"

    # --- collapse ---
    if [[ -d "${SAMPLE_ISOSEQ}/collapse" ]]; then
        mkdir -p "${SAMPLE_DEST}/collapse"
        cp -r "${SAMPLE_ISOSEQ}/collapse/." "${SAMPLE_DEST}/collapse/"
        echo "  [OK] collapse"
    else
        echo "  [SKIP] collapse (not found)"
    fi

    # --- mapped ---
    if [[ -d "${SAMPLE_ISOSEQ}/mapped" ]]; then
        mkdir -p "${SAMPLE_DEST}/mapped"
        cp -r "${SAMPLE_ISOSEQ}/mapped/." "${SAMPLE_DEST}/mapped/"
        echo "  [OK] mapped"

        find "${SAMPLE_ISOSEQ}/mapped" -maxdepth 1 -type f -name "*.bam" -exec cp {} "${BAM_DEST}/" \;
        find "${SAMPLE_ISOSEQ}/mapped" -maxdepth 1 -type f -name "*.bai" -exec cp {} "${BAM_DEST}/" \;
        echo "  [OK] mapped bam/bai -> $BAM_DEST"
    else
        echo "  [SKIP] mapped (not found)"
    fi

    # --- pigeon ---
    if [[ -d "$SAMPLE_PIGEON" ]]; then
        mkdir -p "${SAMPLE_DEST}/pigeon"
        cp -r "${SAMPLE_PIGEON}/." "${SAMPLE_DEST}/pigeon/"
        echo "  [OK] pigeon"
    else
        echo "  [SKIP] pigeon (not found)"
    fi

done

echo ""
echo "Done. Results written to: $DEST"
