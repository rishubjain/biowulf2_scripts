#!/bin/bash
#SBATCH --ntasks=XXXmpinodesXXX
#SBATCH --cpus-per-task=XXXthreadsXXX
#SBATCH --error=XXXerrfileXXX
#SBATCH --output=XXXoutfileXXX

srun --mpi=pmi2 XXXcommandXXX
