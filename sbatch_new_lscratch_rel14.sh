#!/bin/bash
# 
# Script by Rishub Jain, adapted from Mario's biowulf1 script
# 
# 
# READ THIS BEFORE USING THIS SCRIPT:
# 
# This script is designed to work with relion 1.3 and 1.4 on biowulf2 (and with a similar naming convention as the RELION 1.3 tutorial).
# The point of this script is to copy the particle stacks onto the SSD of each node to read the nodes quicker.
# It only works for the classification and refinement steps that use the particle stacks.
#
# Example sbatch submit command using the largemem partition and 15.9G memory per task (inputing the other parameters in the RELION GUI):
# 
# sbatch --mem=1009g --partition=largemem
#
# Things to note:
# - This script will work for RELION 1.3 and 1.4 because the actual naming conventions do not change between these versions. I do not know if this is the case with RELION 1.2
# - The script automatically assumes you are using a node with an 800GiB SSD. If you are using something different, specify the lscratch memory in the RELION GUI.
# - If the particle stack exceeds the maximum memory specified, the script will try to fit in as many of the .mrcs files as it can onto the SSD, and the rest of the particles it will use from your Particles/Micrographs/ folder
# - I do not think there is any point to run this script on nodes with SATA drives. Only use SSD.
# - m is the name of the Micrographs folder. This is by default "Micrographs", so if your Micrographs folder is called something else, you have to specify it by putting --export=m=foldername in the sbatch submit command in the RELION GUI
# - maxs is the maximum number of KiB that you want to use on the node. The default is 838000000 (~799 GiB out of the 800 GiB allocated). If you are using less than this the script should stop when the disk has reached its maximum. However if you are using more than 800GiB, change this variable.
# - It seems like leaving extra space on the disk is only useful if you are constantly writing to the disk. Since this copying process is a one time thing, we want to fill up the SSD as much as we can. The biowulf admins said they do not think filling up the entire disk will decrease reading performance. Also, it seems like filling up the disk completely does not significantly slow down the copying process at the end.
# - To export many variables, use --export=m=Micrographs,maxs=830000000
# - As of Aug 18 2015, it seems like if you export a variable in the RELION gui, it tries to create an entirely new process on each node (for reasons unkown) which messes things up, so do NOT try to export any variables if possible. This bug may be fixed in the future.
# - By default biowulf2 uses hyperthreading, and it seems like if you specify --ntasks-per-core=2, things get messed up (as of July 30 2015). Though I haven't tried this, specifying this option may solve wierd problems you might encounter.
# - The main input particles star file should be in the home directory (the directory the GUI was run from). Otherwise you might encounter some problems. You can also link this starfile. To link files, type the following into the command line:
#	ln -s /complete/path/to/file.star /path/to/home/directory/
# - You cannot have dashes (or any other special characters) in the names of the Particle stack .mrcs files nor in the main particle star file
# - If you do not need 10 days to run, please specify a more reasonable time (less or more, helps you and other users).
# - The star files are changed to have /lscratch/JOBID/ instead of Particles/Micrographs/ as the folder that holds the .mrcs files. The original star file is copied to *.star.save.
# - I initially stored this /lscratch/JOBID/ information in a new star file and edited the command to use that star file, but to do this sucessfully you would have to change the actual rootname of the files (like run1, autopicking, etc.). This can be conflicting in many places, since relion assumes some filesnames to be a certain way. To avoid this hedache, I am just editing over the same star file.
# - The *_data.star files with the particle information, and any other particle star files that were created, will have the particles listed as being in the lscratch directory, so when viewing the particles you will have to change this. You do not need to change this if you are just going from step to step. This script still works if the star files have /lscratch/JOBID/particle.mrcs instead of Particle/Micrographs/particle.mrcs
# - If you want to view the particles manually, you can type this into the command line:
#	cat particles.star | perl -pe "s|/lscratch/.*?/|Particles/Micrographs/|" > particles.star.mod
#	mv particles.star.mod particles.star
# - This script is specific to how biowulf2 functions as of August 2015 (how it specifies the list of nodes, etc.). As biowulf2 changes this script should be changed.
# - Copying speed is around 14.5GB/min using rsh $node cp .... However, using rcp or rsync instead might slightly be faster. I have tested this a little and it doesn't seem to be much of a difference, but you could save time here if done properly.
# - After extensive testing, it seems like compressing the file before transfering does not reduce time, using a variety of different compressions and compression speeds, but instead greatly increases the total time while only slightly decreasing the copying time. Combining the files without compression before copying over also does not seem to save time. Copying to each node's disk is just too fast, and any attempt to decrease the amount of data sent will only increase the total time. 
# - When running Movie processing, I don't think it uses the particle stack from the averaged micrographs. However, if it actually does, the script could be changed to also modify the data.star files of those particle stacks, and copy those stacks to /lscratch. However, the Movie particles alone are often larger than 800GiB, so it probably wouldn't make a difference.
# - Running Movie processing with this script might actually take more time because it would take so long to copy the files. However, I don't think that is the case.
# - At some steps, particularly Movie processing, the script might use files that still have /lscratch/ in the star file, and it is unable to change them (because though the classification and refinement steps only use the .star files given, this may not be the case with the Movie processing steps). You will have to manually change them by doing the steps listed above. To see what files have /lscratch/ in them, you can run the following from your home directory:
# - 	grep -r lscratch *.star | awk '{print $1}' | perl -pe "s|star.*?mrcs|star|" | uniq
# - Allocate the memory by node (using --mem-125g) instead of by cpu (--mem-per-cpu=4g).
# - You can check the progress of the copying process on each node by looking at the .out files, or ussing ssh to access the lscratch directory of each node. If you see that files are no longer copying to the disk, wait a few minutes, and the script should take care of it. If this is still the case, something may have went wrong.
#

# Setting up things

#SBATCH --job-name="rlnXXXnameXXX"
#SBATCH --ntasks=XXXmpinodesXXX
#SBATCH --exclusive
#SBATCH --error=XXXerrfileXXX
#SBATCH --output=XXXoutfileXXX
#SBATCH --time=10-00:00:00
#SBATCH --cpus-per-task=XXXthreadsXXX
#SBATCH --gres=lscratch:800
#SBATCH --mem=125g

module load RELION/1.4-beta-2
echo This is sbatch_new_lscratch_rel14.sh, last modified Aug 18 2015
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

if [ -z "$maxs" ]; then
	maxs=838000000
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

# Modify the star file to indicate that the stack should be read from local /lscratch

cp ${starfile} ${starfile}.save

cat ${starfile} | perl -pe "s|/lscratch/.*?/|/lscratch/${SLURM_JOBID}/|g" > ${starfile}.mod
cat ${starfile}.mod | sed "s|Particles/${m}/|/lscratch/${SLURM_JOBID}/|" > ${starfile}
rm ${starfile}.mod

echo finished modifying star file to use /lscratch/$SLURM_JOBID/

# Get the column that corresponds to the image name

IFS=' # ' read -a col <<< $(grep _rlnImageName ${starfile})
echo "value of variable ${col[0]} is ${col[1]}"


# Get the list of nodes in use

if [ ${#SLURM_JOB_NODELIST} -eq 6 ]; then nlist=$SLURM_JOB_NODELIST; else

IFS=' [ ' read -a nodelist <<< $SLURM_JOB_NODELIST
IFS=' ] ' read -a nodelist <<< ${nodelist[1]}
IFS=' , ' read -a nodes <<< $nodelist
unset nlist

for x in "${nodes[@]}"
do
	IFS=' - ' read -a y <<< $x
	if [ ${#y[*]} -eq 2 ]; then
		for i in $(seq -w ${y[0]} ${y[1]})
		do
			if [ ${#i} -eq 4 ]; then
				temp=$i; else
				temp=$(printf "%04d" $i)
			fi
			nlist=("${nlist[@]}" cn$temp)
		done
	else
		nlist=("${nlist[@]}" cn$y)
	fi
done

fi

echo nodes: ${nlist[@]}

# Now find unique names for stack in the the star file
# and start copying them one by one to avoid overtaxing the file system

echo started copying files at $(date)

filled=0

for dstack in `awk -v c=${col[1]} '{if (NF<= 2) {} else {print $c}}' < ${starfile}| grep -oP "\/\w*\.mrcs" | sed "s|/||" | sort | uniq`
	do

	if [ "$filled" -eq 0 ]; then
		ds=$(rsh $i du -s /lscratch/${SLURM_JOBID}/ | awk '{print $1}')
		if [ "$ds" -gt "$maxs" ]; then
			filled=1
		fi
	fi
	
	if [ "$filled" -eq 1 ]; then
		cat ${starfile} | perl -pe "s|/lscratch/${SLURM_JOBID}/${dstack}|Particles/${m}/${dstack}|" > ${starfile}.mod
		mv ${starfile}.mod ${starfile}
	else

	orisize=$(stat -Lc '%s' "${SLURM_SUBMIT_DIR}/Particles/${m}/${dstack}")
	echo "transferring file ${dstack} of original size ${orisize}"
	
	# start the copy the stack to local /lscratch on each node
	for i in "${nlist[@]}";
		do
		if [ ! -f ${SLURM_SUBMIT_DIR}/Particles/${m}/${dstack} ]; then
			echo "File ${SLURM_SUBMIT_DIR}/Particles/${m}/${dstack} not found ... aborting"
			exit
		fi
		rsh $i cp -L ${SLURM_SUBMIT_DIR}/Particles/${m}/${dstack} /lscratch/${SLURM_JOBID} & 
	done

# verify that copy is finished on each node
	for i in "${nlist[@]}"; do
		count=0
		currsize=$(rsh $i if [ -f /lscratch/${SLURM_JOBID}/${dstack} ]";" then  stat -c '%s' "/lscratch/${SLURM_JOBID}/${dstack}" ";" else echo 0 ";" fi)
		temps=$currsize
		echo Size of file /lscratch/$SLURM_JOBID/$dstack in node $i is $currsize
		while [ $currsize -lt $orisize ]; do
			sleep .5
			currsize=$(rsh $i if [ -f /lscratch/${SLURM_JOBID}/${dstack} ]";" then  stat -c '%s' "/lscratch/${SLURM_JOBID}/${dstack}" ";" else echo 0 ";" fi)
			echo node ${i}: copied ${currsize} of ${orisize}
			count=$(( count+1 ))

			# If it is not copying anything for ~15 secconds, use the rest of the files from the Particles/Micrographs directory
			if [ "$count" -gt 30 ]; then
				ds=$(rsh $i du -s /lscratch/${SLURM_JOBID}/ | awk '{print $1}')
				if [ "$ds" -gt "$maxs" ]; then
					echo -e "\nParticle stack is too large for the lscratch space (${maxs} KiB). Changing star file to use the rest of the particles from the Particles/Micrographs directory.\n"
					filled=1
					cat ${starfile} | perl -pe "s|/lscratch/${SLURM_JOBID}/${dstack}|Particles/${m}/${dstack}|" > ${starfile}.mod
					mv ${starfile}.mod ${starfile}
					break 2
				fi
				if [ "$temps" -eq "$currsize" ]; then 
					echo -e "\nFILES NOT COPYING FOR SOME UNKNOWN ERROR! Using the rest of the files from Particles/Micrographs directory.\n"
					filled=1
					cat ${starfile} | perl -pe "s|/lscratch/${SLURM_JOBID}/${dstack}|Particles/${m}/${dstack}|" > ${starfile}.mod
					mv ${starfile}.mod ${starfile}
					break 2
				fi
				temps=$currsize
				count=0
			fi
		done
	done
	if [ "$filled" -eq 1 ]; then
		for i in "${nlist[@]}"; do
			rsh $i rm /lscratch/${SLURM_JOBID}/${dstack}
		done
	fi
	fi
done

echo finsihed copying files at $(date)
echo "All stacks transferred to /lscratch/$SLURM_JOBID"

# run relion
srun --mpi=pmi2 $command

