#!/bin/bash
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=01:00:00
#SBATCH --output=logs/debug_pbfusion_%j.out
#SBATCH --error=logs/debug_pbfusion_%j.err
#SBATCH --job-name=debug_pbfusion

set -e

echo "Script start: $( date +"%Y-%m-%d %T" )"
echo "HOSTNAME: ${HOSTNAME}"

WORKDIR=/cluster/home/tmamidi/tarun/kinnex_try/kinnex-nf/nextflow_work/91/49ad469636cf0b697bb84c5c27036b
PBFUSION=/cluster/home/tmamidi/.nextflow/conda/scKinnex-77149910c7f37373d446d677d8fb70d5/bin/pbfusion
OUTLOG=/cluster/home/tmamidi/tarun/kinnex_try/kinnex-nf/logs/pbfusion_gdb_${SLURM_JOB_ID}.log

echo "Running pbfusion directly with RUST_BACKTRACE=1..."
export RUST_BACKTRACE=1

set +e
$PBFUSION discover \
    --gtf $WORKDIR/gencode.v39.annotation.sorted.gtf \
    --output-prefix /tmp/caHF-034-debug \
    --threads 1 \
    $WORKDIR/caHF-034-CPP-T.mapped.bam 2>&1 | tee $OUTLOG
echo "pbfusion exit code: $?"
set -e

echo ""
echo "GDB output saved to: $OUTLOG"
echo "Done: $( date +"%Y-%m-%d %T" )"
