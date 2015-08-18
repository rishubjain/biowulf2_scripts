#!/bin/bash
# 
# Script by Rishub Jain, adapted from Mario's biowulf1 script
# 
# 
# READ THIS BEFORE USING THIS SCRIPT:
# 
# This script is designed to work with relion 1.3 and 1.4 on biowulf2 (and with a similar naming convention as the RELION 1.3 tutorial).
#
# Example sbatch submit command using the largemem partition and 15.9G memory per task (inputing the other parameters in the RELION GUI):
# 
# sbatch --mem=1009g --partition=largemem
#
# Things to note:
# - m is the name of the Micrographs folder. This is by default "Micrographs", so if your Micrographs folder is called something else, you have to specify it by putting --export=m=foldername in the sbatch submit command in the RELION GUI
# - By default biowulf2 uses hyperthreading, and it seems like if you specify --ntasks-per-core=2, things get messed up (as of July 30 2015). Though I haven't tried this, specifying this option may solve wierd problems you might encounter.
# - The main input particles star file should be in the home directory (the directory the GUI was run from). Otherwise you might encounter some problems. You can also link this starfile. To link files, type the following into the command line:
#       ln -s /complete/path/to/file.star /path/to/home/directory/
# - You cannot have dashes (or any other special characters) in the names of the Particle stack .mrcs files nor in the main particle star file
# - If you do not need 10 days to run, please specify a more reasonable time (less or more, helps you and other users).
# - The star files are changed to have /lscratch/JOBID/ instead of Particles/Micrographs/ as the folder that holds the .mrcs files. The original star file is copied to *.star.save.
# - I initially stored this /lscratch/JOBID/ information in a new star file and edited the command to use that star file, but to do this sucessfully you would have to change the actual rootname of the files (like run1, autopicking, etc.). This can be conflicting in many places, since relion assumes some filesnames to be a certain way. To avoid this hedache, I am just editing over the same star file.
# - The *_data.star files with the particle information, and any other particle star files that were created, will have the particles listed as being in the lscratch directory, so when viewing the particles you will have to change this. You do not need to change this if you are just going from step to step. This script still works if the star files have /lscratch/JOBID/particle.mrcs instead of Particle/Micrographs/particle.mrcs
# - If you want to view the particles manually, you can type this into the command line:
#       cat particles.star | perl -pe "s|/lscratch/.*?/|Particles/Micrographs/|" > particles.star.mod
#       mv particles.star.mod particles.star
# - This script is specific to how biowulf2 functions as of August 2015 (how it specifies the list of nodes, etc.). As biowulf2 changes this script should be changed.
# - Allocate the memory by node (using --mem-125g) instead of by cpu (--mem-per-cpu=4g).


# Setting up things

#SBATCH --job-name="rlnXXXnameXXX"
#SBATCH --ntasks=XXXmpinodesXXX
#SBATCH --exclusive
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

