#!/bin/bash
# 
# Script by Rishub Jain, adapted from Mario's biowulf1 script
# 
# 
# READ THIS BEFORE USING THIS SCRIPT:
# 
# This script is designed to work with relion 1.3 and 1.4 on biowulf2. It is meant to run as if you have extracted particles using RELION, but if you didn't you can change things to make it still work.
# This script just changes any star filenames from /lscratch/JOBID/ to Particles/Micrographs/, and sets all the biowulf2 parameters.
#
# GUI Information:
# Number of MPI procs: This is the number of different processes (tasks) you want to run
# Number of threads: This is the number of CPUs allocated to each task. Change this from the default of 1 if you need more memory per task.
# Available RAM (in Gb) per thread: This is the amount of memory allocated per CPU. You can find this out by dividing the memory per node by the number of CPUs available
#
# Example sbatch submit command within RELION using the largemem partition and 32G memory per task, with 32 tasks:
# Number of MPI procs: 32
# Number of threads: 2
# Available RAM (in Gb) per thread: 15.9 
# Submit to queue?: Yes
# Queue name: <LEAVE BLANK>
# Queue submit command: sbatch --mem=1009g --partition=largemem
# Standard submission script: sbatch_new_lscratch_rel14.sh (or wherever it is located)
#
#
# Things to note:
# - You should have a good idea about how clusters, specifically biowulf2, work when using this script (please read the biowulf2 user guide).
# - This script will work for RELION 1.3 and 1.4 because the actual naming conventions do not change between these versions. It probably also works with RELION 1.2, but I am not sure.
# - The script assumes that the particle stack(s) are in the Particles/Micrographs/ directory, which should be in the home directory (the directory the GUI was run from). If this is not the case, an easy fix is to create a Particles/Micrographs/ directory in the home directory, and link the Particle stack from wherever it is to the Particles/Micrographs/ directory. You will also have to change this in the input star file (or in the data.star if you are continuing a run) to also include this. The particles in the star file must be in the format of Particles/<folder name>/<particle>.mrcs OR /lscratch/<JOB ID>/<particle>.mrcs.
# - To link files, type the following into the command line:
#		ln -s /complete/path/to/file.mrcs /path/to/home/directory/
# - m is the name of the Micrographs folder (which is also the Particles/<folder name>/ folder, which will have the same folder name if extracted through RELION). This is by default "Micrographs", so if your Micrographs folder is called something else, you have to specify it by putting --export=m=foldername in the sbatch submit command in the RELION GUI
# - To export multiple variables, use --export=ALL,m=Micrographs,maxs=830000000 in the submit command in the RELION GUI. You must have the =ALL at the beginning.
# - If you do not need 10 days to run, you should specify a more reasonable time using --time=4-00:00:00.
# - This script is specific to how biowulf2 functions as of August 2015 (how it specifies the list of nodes, etc.). As biowulf2 changes this script should be changed.
# - By default biowulf2 uses hyperthreading, and it seems like if you specify --ntasks-per-core=2, things get messed up (as of July 30 2015). Though I haven't tried this, specifying this option may solve wierd problems you might encounter.
# - The *_data.star files with the particle information, and any other particle star files that were created, will have the particles listed as being in the lscratch directory, so when viewing the particles you will have to change this. You do not need to change this if you are just going from step to step. This script still works if the star files have /lscratch/JOBID/particle.mrcs instead of Particle/Micrographs/particle.mrcs
# - If you want to view the particles manually, you can type this into the command line:
#       cat particles.star | perl -pe "s|/lscratch/.*?/|Particles/Micrographs/|" > particles.star.mod
#       mv particles.star.mod particles.star
# - This script is specific to how biowulf2 functions as of August 2015 (how it specifies the list of nodes, etc.). As biowulf2 changes this script should be changed.
# - Allocate the memory by node (using --mem-125g) instead of by cpu (--mem-per-cpu=4g).
#

# Setting up things

#SBATCH --job-name="rlnXXXnameXXX"
#SBATCH --ntasks=XXXmpinodesXXX
#SBATCH --error=XXXerrfileXXX
#SBATCH --output=XXXoutfileXXX
#SBATCH --time=10-00:00:00
#SBATCH --cpus-per-task=XXXthreadsXXX
#SBATCH --mem=125g

module load RELION/1.4-beta-2
echo This is sbatch_simple.sh, last modified Aug 12 2015
echo run started on: $(date)
echo running on $SLURM_SUBMIT_DIR
echo with job id $SLURM_JOBID
echo with nodes: $SLURM_JOB_NODELIST
command=$(echo XXXcommandXXX)
echo with command:
echo $command
cd $SLURM_SUBMIT_DIR

# Set the Micrographs directory

if [ -z "$m" ]; then
	m=Micrographs
fi

# Check if you are continuing a run or running movie processing

c=`echo $command|grep -o "\-\-continue.*star"`
mov=`echo $command|grep -o "realign_movie_frames"`

# get the name of the starfile from the command

if [ -z "$c" ]; then
	if [ -z "$mov" ]; then
		# Normal run
		starfile=`echo $command|grep -oP "\-\-i.*star"|sed "s|--i ||"`
	else
		echo "RUNNING MOVIE PROCESSING WITHOUT CONTINUING RUN!"
	fi
else
	if [ -z "$mov" ]; then
		# Continuing previous run, not movie processing
		opt=`echo $command|grep -o "\-\-continue.*optimiser.star"|sed "s|--continue ||"`
		starfile=${opt/"optimiser"/"data"}
	else
		# Continuing previous run with movie processing
		starfile=`echo $command|grep -oP "\-\-realign_movie_frames.*star"|sed "s|--realign_movie_frames ||"`
	fi
fi

echo "star file is: $starfile"

# Modify the star file to indicate that the stack should be read from Particles/Micrographs/

cp ${starfile} ${starfile}.save

cat ${starfile} | perl -pe "s|/lscratch/.*?/|Particles/${m}/|" > ${starfile}.mod
mv ${starfile}.mod ${starfile}

echo finished modifying star file to use Particles/${m}/

# run relion
srun --mpi=pmi2 $command

