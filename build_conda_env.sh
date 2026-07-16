#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=8G
#SBATCH --time=04:00:00
#SBATCH --output=logs/build_conda_%j.out
#SBATCH --error=logs/build_conda_%j.err
#SBATCH --job-name=build_conda_env

set -e

echo "Script start: $( date +"%Y-%m-%d %T" )"
echo "HOSTNAME: ${HOSTNAME}"

# Initialize conda
source /software/python/conda3/etc/profile.d/conda.sh

# Set to where you cloned kinnex-nf
PROJECT_DIR="/path/to/kinnex-nf"

# Nextflow-computed conda cache prefix (hash matches assets/scKinnex_simple.yml;
# must match what the `conda` profile resolves to for the pre-build to be reused)
ENV_PREFIX="${HOME}/.nextflow/conda/scKinnex-77149910c7f37373d446d677d8fb70d5"
ENV_YML="${PROJECT_DIR}/assets/scKinnex_simple.yml"

if conda env list | grep -q "${ENV_PREFIX}"; then
    echo "Conda environment already exists at: ${ENV_PREFIX}"
    echo "Updating environment..."
    conda env update --prefix "${ENV_PREFIX}" --file "${ENV_YML}" --prune
    echo "Conda environment updated successfully."
else
    echo "Creating conda environment at: ${ENV_PREFIX}"
    conda env create --prefix "${ENV_PREFIX}" --file "${ENV_YML}"
    echo "Conda environment created successfully."
fi

echo "Done: $( date +"%Y-%m-%d %T" )"
