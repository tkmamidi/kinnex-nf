#!/usr/bin/env bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=4G
#SBATCH --time=4:00:00
#SBATCH --output=logs/copy_results_%j.out
#SBATCH --error=logs/copy_results_%j.err
#SBATCH --job-name=copy_results

# copy_results_by_sample.sh
#
# Reorganizes pipeline output from step-based layout into per-sample layout:
#   SOURCE/isoseq/SAMPLE/collapse/      -> DEST/SAMPLE/collapse/
#   SOURCE/isoseq/SAMPLE/mapped/        -> DEST/SAMPLE/mapped/
#   SOURCE/pigeon/SAMPLE/               -> DEST/SAMPLE/pigeon/
#   SOURCE/isocall/profiles/SAMPLE/     -> DEST/SAMPLE/isocall/
#   SOURCE/variant_calling/SAMPLE/      -> DEST/SAMPLE/variant_calling/
#   SOURCE/fusion_calling/SAMPLE/       -> DEST/SAMPLE/fusion_calling/
#   SOURCE/pipeline_info/versions.yml   -> DEST/SAMPLE/pipeline_info/
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
SOURCE="results"  # <-- set this to the source directory relative to project dir or absolute path
#------------------------------------------------------------------------------

# Resolve source relative to project dir if not absolute
if [[ "$SOURCE" != /* ]]; then
    SOURCE="${PROJECT_DIR}/${SOURCE}"
fi

SOURCE="$(realpath "$SOURCE")"

ISOSEQ_DIR="${SOURCE}/isoseq"
PIGEON_DIR="${SOURCE}/pigeon"
ISOCALL_DIR="${SOURCE}/isocall/profiles"
VARIANT_DIR="${SOURCE}/variant_calling"
FUSION_DIR="${SOURCE}/fusion_calling"
VERSIONS_FILE="${SOURCE}/pipeline_info/versions.yml"

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

    # --- isocall ---
    SAMPLE_ISOCALL="${ISOCALL_DIR}/${SAMPLE}"
    if [[ -d "$SAMPLE_ISOCALL" ]]; then
        mkdir -p "${SAMPLE_DEST}/isocall"
        cp -r "${SAMPLE_ISOCALL}/." "${SAMPLE_DEST}/isocall/"
        echo "  [OK] isocall"
    else
        echo "  [SKIP] isocall (not found)"
    fi

    # --- variant_calling ---
    SAMPLE_VARIANT="${VARIANT_DIR}/${SAMPLE}"
    if [[ -d "$SAMPLE_VARIANT" ]]; then
        mkdir -p "${SAMPLE_DEST}/variant_calling"
        cp -r "${SAMPLE_VARIANT}/." "${SAMPLE_DEST}/variant_calling/"
        echo "  [OK] variant_calling"
    else
        echo "  [SKIP] variant_calling (not found)"
    fi

    # --- fusion_calling ---
    SAMPLE_FUSION="${FUSION_DIR}/${SAMPLE}"
    if [[ -d "$SAMPLE_FUSION" ]]; then
        mkdir -p "${SAMPLE_DEST}/fusion_calling"
        cp -r "${SAMPLE_FUSION}/." "${SAMPLE_DEST}/fusion_calling/"
        echo "  [OK] fusion_calling"
    else
        echo "  [SKIP] fusion_calling (not found)"
    fi

    # --- pipeline_info (versions.yml) ---
    if [[ -f "$VERSIONS_FILE" ]]; then
        mkdir -p "${SAMPLE_DEST}/pipeline_info"
        cp "$VERSIONS_FILE" "${SAMPLE_DEST}/pipeline_info/"
        echo "  [OK] pipeline_info/versions.yml"
    fi

done

# --- shared isocall ref.isoforms.gz ---
REF_ISOFORMS="${SOURCE}/isocall/ref.isoforms.gz"
if [[ -f "$REF_ISOFORMS" ]]; then
    mkdir -p "${DEST}/isocall"
    cp "$REF_ISOFORMS" "${DEST}/isocall/"
    echo "[OK] isocall/ref.isoforms.gz -> ${DEST}/isocall/"
else
    echo "[SKIP] isocall/ref.isoforms.gz (not found)"
fi

echo ""
echo "Done. Results written to: $DEST"
