#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --mem=16G
#SBATCH --time=72:00:00
#SBATCH --output=logs/kinnex_nf_%j.out
#SBATCH --error=logs/kinnex_nf_%j.err
#SBATCH --job-name=Kinnex_nf

set -e

echo "Script start: $( date +"%Y-%m-%d %T" )"
echo "HOSTNAME: ${HOSTNAME}"

#------------------------------------------------------------------------------
# CONFIGURATION - MODIFY THESE PATHS FOR YOUR ENVIRONMENT
#------------------------------------------------------------------------------

# >>> SET THIS TO YOUR PROJECT DIRECTORY <<<
PROJECT_DIR="/cluster/home/tmamidi/tarun/kinnex_try/kinnex-nf"

# Input samplesheet (TSV: POOL_NAME, HIFI_BAM, LIMA_CSV)
INPUT_TSV="${PROJECT_DIR}/assets/samplesheet.tsv"

# Output directory
OUTDIR="${PROJECT_DIR}/results"

# Nextflow work directory (stores intermediate files - must be on shared filesystem)
WORK_DIR="${PROJECT_DIR}/nextflow_work"

# Temp directory
TMPDIR_PATH="/scratch"

# Pipeline location (where you cloned/copied kinnex-nf)
PIPELINE_DIR="${PROJECT_DIR}"

# Reference files (default paths - modify if needed)
MAS8_PRIMERS="/analysis/cloud_projects/research/cancer/scKinnex/reference/MAS-Seq_Adapter_v3/mas8_primers.fasta"
ISOSEQ_PRIMERS="/analysis/cloud_projects/research/cancer/scKinnex/reference/REF-primers/IsoSeq_v2_primers_12.fasta"
REF_GENOME="/analysis/cloud_projects/research/cancer/IsoSeq/pigeon_reference/human_GRCh38_no_alt_analysis_set.fasta"
REF_ANNOTATION="/analysis/cloud_projects/research/cancer/IsoSeq/pigeon_reference/gencode.v39.annotation.sorted.gtf"

# Isocall binary (download from https://github.com/PacificBiosciences/isocall/releases)
ISOCALL_BINARY="/analysis/cloud_projects/research/cancer/isocall_v0_15_0"

#------------------------------------------------------------------------------
# ENVIRONMENT SETUP
#------------------------------------------------------------------------------

# Set TMPDIR
export TMPDIR="${TMPDIR_PATH}"
export SLURM_TMPDIR="${TMPDIR_PATH}"
[[ -d ${TMPDIR} ]] || mkdir -p ${TMPDIR}

# Create work directory
[[ -d ${WORK_DIR} ]] || mkdir -p ${WORK_DIR}

# Unset Python paths to avoid conflicts
unset PYTHONPATH
unset PYTHONHOME

# Initialize conda (needed for Nextflow to use conda)
source /software/python/conda3/etc/profile.d/conda.sh

# Java 17 (required for Nextflow)
export JAVA_HOME="/software/java/java11"
export PATH="${JAVA_HOME}/bin:$PATH"

# Nextflow JAR file (using Java directly due to permission issues)
NEXTFLOW_JAR="/software/nextflow/current/nextflow-23.04.4-all"

# JVM options for the main process
JAVA_OPTS="--add-opens java.management/com.sun.jmx.mbeanserver=ALL-UNNAMED \
--add-opens java.base/java.lang=ALL-UNNAMED \
--add-opens java.base/java.util=ALL-UNNAMED \
--add-opens java.base/java.lang.reflect=ALL-UNNAMED \
--add-opens java.base/java.nio=ALL-UNNAMED \
--add-opens java.base/sun.nio.ch=ALL-UNNAMED \
--add-opens java.base/java.io=ALL-UNNAMED"

# NXF_OPTS for Nextflow's internal processes (must be exported)
export NXF_OPTS="${JAVA_OPTS}"

#------------------------------------------------------------------------------
# RUN NEXTFLOW PIPELINE
#------------------------------------------------------------------------------

echo "Starting Nextflow pipeline..."
echo "Input: ${INPUT_TSV}"
echo "Output: ${OUTDIR}"
echo "Work dir: ${WORK_DIR}"

java ${JAVA_OPTS} -jar ${NEXTFLOW_JAR} -log logs/.nextflow.log run ${PIPELINE_DIR}/main.nf \
    -profile slurm,conda \
    -w ${WORK_DIR} \
    --input ${INPUT_TSV} \
    --mas8_primers ${MAS8_PRIMERS} \
    --isoseq_primers ${ISOSEQ_PRIMERS} \
    --ref_genome ${REF_GENOME} \
    --ref_annotation ${REF_ANNOTATION} \
    --isocall_binary ${ISOCALL_BINARY} \
    --tmpdir ${TMPDIR} \
    --outdir ${OUTDIR} \
    -resume

#------------------------------------------------------------------------------
# COMPLETION
#------------------------------------------------------------------------------

echo "Pipeline completed"
echo "Script end: $( date +"%Y-%m-%d %T" )"
