#!/bin/bash
# 
# Script by Rishub Jain, adapted from Mario's biowulf1 script
# 
# 
# READ THIS BEFORE USING THIS SCRIPT:
# 
# This script is designed to work with relion 1.3 and 1.4 on biowulf2. It is meant to run as if you have extracted particles using RELION, but if you didn't you can change things to make it still work.
# The point of this script is to copy the particle stacks onto the SSD of each node so that reading the particle stacks will be quicker.
# It only works for the classification and refinement steps that use the particle stacks.
#
# GUI Information:
# Number of MPI procs: This is the number of different processes (tasks) you want to run
# Number of threads: This is the number of CPUs allocated to each task. Change this from the default of 1 if you need more memory per task.
# Available RAM (in Gb) per thread: This is the amount of memory allocated per CPU. You can find this out by dividing the memory per node by the number of CPUs available
#
# Example sbatch submit command using the largemem partition and 32G memory per task, with 32 tasks:
# Number of MPI procs: 32
# Number of threads: 2
# Available RAM (in Gb) per thread: 15.9 
# Submit to queue?: Yes
# Queue name: <LEAVE BLANK>
# Queue submit command: sbatch --mem=1009g --partition=largemem
# Standard submission script: sbatch_new_lscratch_rel14.sh (or wherever it is located)
#
#
# Things to note before running this script:
# - You should have a good idea about how clusters, specifically biowulf2, work when using this script (please read the biowulf2 user guide). You must run this script using entirely free nodes.
# - This script will work for RELION 1.3 and 1.4 because the actual naming conventions do not change between these versions. It probably also works with RELION 1.2, but I am not sure.
# - The script assumes that the particle stack(s) are in the Particles/Micrographs/ directory, which should be in the home directory (the directory the GUI was run from). If this is not the case, an easy fix is to create a Particles/Micrographs/ directory in the home directory, and link the Particle stack from wherever it is to the Particles/Micrographs/ directory. You will also have to change this in the input star file (or in the data.star if you are continuing a run) to also include this. The particles in the star file must be in the format of Particles/<folder name>/<particle>.mrcs OR /lscratch/<JOB ID>/<particle>.mrcs.
# - To link files, type the following into the command line:
#		ln -s /complete/path/to/file.mrcs /path/to/home/directory/
# - The script automatically assumes you are using a node with an 800GiB SSD. If you are using something different, specify the lscratch memory in the RELION GUI using --gres=lscratch:800.
# - Only use SSD nodes if possible, not SATA. SATA will be slower, but your total time might still increase by using this script on SATA.
# - m is the name of the Micrographs folder. This is by default "Micrographs", so if your Micrographs folder is called something else, you have to specify it by putting --export=m=foldername in the sbatch submit command in the RELION GUI
# - maxs is the maximum number of KiB that you want to use on the node. The default is 838000000 (~799 GiB out of the 800 GiB allocated). If you are using less than this the script should stop when the disk has reached its maximum (but you should still change this variable. 418400000 Kib = ~399 Gib). However if you are using more than 800GiB, you must change this variable.
# - It seems like leaving extra space on the disk is only useful if you are constantly writing to the disk. Since this copying process is a one time thing, we want to fill up the SSD as much as we can. The biowulf admins said they do not think filling up the entire disk will decrease reading performance. Also, it seems like filling up the disk completely does not significantly slow down the copying process at the end.
# - If the particle stack exceeds the maximum memory specified, the script will try to fit in as many of the .mrcs files as it can onto the SSD, and the rest of the particles it will use from your Particles/Micrographs/ folder. Since it tries to put as many particles as it can onto the /lscratch/ directory, and because the SPY pipeline often outputs one big particle stack, it is a time consuming process to create new particle stacks to be copied. Though this is done automatically if there isn't enough memory on /lscratch/, if you want to only copy the particles that are used, you can specify the "separate" variable to be 1 by doing --export=ALL,separate=1. Since this takes around an hour for large data, this will (most probably) not speed up the copying process. However, if your particle stacks are bigger that what you can fit on the /lscratch/ space, doing this could greatly speed up your runs.
# - If you set the "separate" variable to -1, it will not split the stack even if it is bigger than the /lscratch/ directory. This may be better at times if your particle stack files are very small, and when creating two new stacks would not help performance much.
# - To export multiple variables, use --export=ALL,m=Micrographs,maxs=830000000 in the submit command in the RELION GUI. You must have the =ALL at the beginning.
# - The main input particles star file should be in the home directory. Otherwise you might encounter some problems (I haven't tested this yet, but it should work either way now). You can also link this starfile.
# - You may have problems if there are dashes (or any other special characters) in the names of the Particle stack .mrcs files or in the main particle star file. I think I fixed this but have not tested it thoroughly.
# - If you do not need 10 days to run, you should specify a more reasonable time using --time=4-00:00:00.
# - The star files are changed to have /lscratch/JOBID/ instead of Particles/Micrographs/ as the folder that holds the .mrcs files. The original star file is copied to *.star.save.
# - I initially stored this /lscratch/JOBID/ information in a new star file and edited the command to use that star file, but to do this sucessfully you would have to change the actual rootname of the files (like run1, autopicking, etc.). This can be conflicting in many places, since relion assumes some filesnames to be a certain way. To avoid this hedache, I am just editing over the same star file.
# - The *_data.star files with the particle information, and any other particle star files that were created, will have the particles listed as being in the lscratch directory, so when viewing the particles you will have to change this. You do not need to change this if you are just going from step to step. This script still works if the star files have /lscratch/JOBID/particle.mrcs instead of Particle/Micrographs/particle.mrcs
# - If you want to view the particles manually, you can type this into the command line:
#		cat particles.star | perl -pe "s|/lscratch/.*?/|Particles/Micrographs/|" > particles.star.mod
#		mv particles.star.mod particles.star
# - This script is specific to how biowulf2 functions as of August 2015 (how it specifies the list of nodes, etc.). As biowulf2 changes this script should be changed.
# - By default biowulf2 uses hyperthreading, and it seems like if you specify --ntasks-per-core=2, things get messed up (as of July 30 2015). Though I haven't tried this, specifying this option may solve wierd problems you might encounter.
#
#
# Things to note if you are changing this script, or if you are having issues:
# - If you want this script to be run straight after going through the SPY Pipeline, you will have to edit this script. You can still run this script if you do the modifications I said above, which doesn't take long. I did this because it made things easier, and the majority of what I did was working with Particles generated through RELION, which creates this directory.
# - If you specify the "separate" variable, or if there isn't enough space on /lscratch/, it combines all of the particle stacks into two stacks: One which will fit almost exactly onto the /lscratch/ space, and one which will be stored in your Particles/Micrographs/ directory. Both of these combined will have only the particles from the input star file. If you specified the "separate" variable to be 1, and the particle stack will fit into the /lscratch/ directory, it will just create one particle stack of only the particles being used.
# - newstack is not the most efficient method, so if someone can make a method that does newstack in parallel, or at least more efficiently, it would greatly speed up the process of creating the new stacks, and the copying process would also probably be sped up because less particles are being copied.
# - Copying speed is around 14.5GB/min using rsh $node cp .... However, using rcp or rsync instead might slightly be faster. I have tested this a little and it doesn't seem to be much of a difference, but you could save time here if done properly.
# - After extensive testing, it seems like compressing the file before transfering does not reduce time, using a variety of different compressions and compression speeds (even compressing in parallel), but instead greatly increases the total time while only slightly decreasing the copying time. Combining the files without compression before copying over also does not seem to save time. Copying to each node's disk is just too fast, and any attempt to decrease the amount of data sent will only increase the total time. 
# - It also seems like copying many files onto each node at the same time increases the speed by about 15%, which would save about 10 minutes when copying 800G. It may be worth testing.
# - When running Movie processing, I don't think it uses the particle stack from the averaged micrographs. However, if it actually does, the script could be changed to also modify the data.star files of those particle stacks, and copy those stacks to /lscratch. However, the Movie particles alone are often larger than 800GiB, so it probably wouldn't make a difference.
# - At some steps, particularly Movie processing, the script might use files that still have /lscratch/ in the star file, and it is unable to change them (because though the classification and refinement steps only use the .star files given, this may not be the case with the Movie processing steps). You will have to manually change them by doing the steps listed above. To see what files have /lscratch/ in them, you can run the following from your home directory:
# - 	grep -r lscratch *.star | awk '{print $1}' | perl -pe "s|star.*?mrcs|star|" | uniq
# - Allocate the memory by node (using --mem-125g) instead of by cpu (--mem-per-cpu=4g).
# - You can check the progress of the copying process on each node by looking at the .out files, or ussing ssh to access the lscratch directory of each node. If you see that files are no longer copying to the disk, wait a few minutes, and the script should take care of it. If this is still the case, something may have went wrong.
# - Copying the particles to /lscratch/ significantly saves time in every step of the process before movie processing. Though running movie processing with this script might actually take more time because it would take so long to copy the files, I do not think this is the case.
# - I ran out of time to do intense testing on real data, but everything should work. There may be small bugs.
# - It may be worth experimenting with making this not limited to exclusive nodes. I think you will not loose time if you do this, so it is worth a try.
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
echo This is sbatch_new_lscratch_rel14.sh, last modified Aug 21 2015
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

if [ -z "$separate" ]; then
	separate=0
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
		echo "ERROR: RUNNING MOVIE PROCESSING WITHOUT CONTINUING RUN!"
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

unset ustacks
unset ustacks2
unset stacknums
declare -A stacknums
scount=0

# Slightly slower than:
# for dstack in `awk -v c=${col[1]} '{if (NF<= 2) {} else {print $c}}' < ${starfile}| grep -oP "\/\w*\.mrcs" | sed "s|/||" | sort | uniq` 
# but works with dashes, and is faster than using basename

while read dstack
do
	scount=$(( scount + 1 ))
	stacknums[$dstack]=$scount
	ustacks=("${ustacks[@]}" $dstack)
	ustacks2=("${ustacks2[@]}" Particles/$m/$dstack)
done < <(for p in `awk -v c=${col[1]} '{if (NF<= 2) {} else {print $c}}' ${starfile}`; do echo ${p##*/}; done | uniq)


stacklen=$(du -cs ${ustacks2[*]} | tail -n 1 | awk '{print $1}')
if ( [ $stacklen -gt $maxs ] || [ $separate -gt 0 ] ) && [ $separate -ne -1 ]; then

module load IMOD

numparts=0

for x in ${ustacks2[*]}
do
	ts=$( header $x -s | awk '{print $3}' )
	numparts=$(( numparts + ts ))
done

maxp=$(( (maxs - 10000) / (stacklen/numparts) ))

unset secslist
unset restplist
unset secs
declare -A secs
unset restp
declare -A restp
unset secssize
declare -A secssize
unset restpsize
declare -A restpsize
unset pvals
declare -A pvals
unset wstack
declare -A wstack
unset addfsecs
declare -A addfsecs
unset addfrestp
declare -A addfrestp

overf=0
secscount=0
restpcount=0
pwrit=0

# one file, reduces some overhead

for parts in `awk -v c=${col[1]} '{if (NF<= 2) {} else {print $c}}' < ${starfile}`
do

	IFS=' @ ' read -a pinfo <<< $parts 
        pnum=${pinfo[0]}
	pstack=${pinfo[1]}

if [ $pwrit -gt $maxp ]; then
	overf=1
	if [ -z "${restp[$pstack]}" ]; then
		restp[$pstack]="$pnum"
		restplist=("${restplist[@]}" $pstack)
		restpsize[$pstack]=1
		restpcount=$(( restpcount + 1 ))
	else
		restpsize[$pstack]=$(( ${restpsize[$pstack]} + 1 ))
		restp[$pstack]="${restp[$pstack]},${pnum}"
	fi
        pvals[${stacknums[$pstack]},$pnum]=${restpsize[$pstack]}
	wstack[${stacknums[$pstack]},$pnum]=Particles/$m/not_copied_stack_${SLURM_JOBID}.mrcs

else

	if [ -z "${secs[$pstack]}" ]; then
		secs[$pstack]="$pnum"
		secslist=("${secslist[@]}" $pstack)
		secssize[$pstack]=1
		secscount=$(( secscount + 1 ))
	else
		secssize[$pstack]=$(( ${secssize[$pstack]} + 1 ))
		secs[$pstack]="${secs[$pstack]},${pnum}"
	fi
        pvals[${stacknums[$pstack]},$pnum]=${secssize[$pstack]}
	wstack[${stacknums[$pstack]},$pnum]=/lscratch/${SLURM_JOBID}/copied_stack_${SLURM_JOBID}.mrcs
fi

pwrit=$(( pwrit + 1 ))

done

echo "There are $pwrit particles"

caddf=0

echo $secscount > copied_particles_${SLURM_JOBID}.in
for x in ${secslist[*]}
do
	echo $x >> copied_particles_${SLURM_JOBID}.in
	echo ${secs[$x]} >> copied_particles_${SLURM_JOBID}.in
	addfsecs[$x]=$caddf
	caddf=$(( caddf + ${secssize[$x]} ))
done

# There is not a native way to write to all /lscratch/ directories at once, but I could modify the newstack command to do so. This would save time.

newstack -fr -filei copied_particles_${SLURM_JOBID}.in -ou Particles/$m/copied_stack_${SLURM_JOBID}.mrcs &
PIDCOP=$!

if [ $overf -eq 1 ]; then

caddf=0

echo $restpcount > not_copied_particles_${SLURM_JOBID}.in
for x in ${restplist[*]}
do
	echo $x >> not_copied_particles_${SLURM_JOBID}.in
	echo ${restp[$x]} >> not_copied_particles_${SLURM_JOBID}.in
	addfrestp[$x]=$caddf
	caddf=$(( caddf + ${restpsize[$x]} ))
done

newstack -fr -filei not_copied_particles_${SLURM_JOBID}.in -ou Particles/$m/not_copied_stack_${SLURM_JOBID}.mrcs &
PIDNCOP=$!

fi

rm ${starfile}.mod

while read line
do
if [ `echo $line | awk '{print NF}'` -le 2 ]; then
	echo $line >> ${starfile}.mod
else
	parts=$(echo $line | awk -v c=${col[1]} '{print $c}')	
        IFS=' @ ' read -a pinfo <<< $parts
        pnum=${pinfo[0]}
        pstack=${pinfo[1]}
	if [ "${wstack[${stacknums[$pstack]},$pnum]}" = "/lscratch/${SLURM_JOBID}/copied_stack_${SLURM_JOBID}.mrcs" ]; then
		adv=${addfsecs[$pstack]}
	else
		adv=${addfrestp[$pstack]}
	fi
	echo $line | awk -v pn=$( printf "%07d%s" $(( ${pvals[${stacknums[$pstack]},$pnum]} + adv )) ) -v pname="${wstack[${stacknums[$pstack]},$pnum]}" -v c=${col[1]} '{$c=pn"@"pname}1' >> ${starfile}.mod

fi
done < ${starfile}

wait $PIDCOP
if [ $overf -eq 1 ]; then
	wait $PIDNCOP
fi

echo started copying files at $(date)

dstack="copied_stack_${SLURM_JOBID}.mrcs"

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
		sleep 5
		currsize=$(rsh $i if [ -f /lscratch/${SLURM_JOBID}/${dstack} ]";" then  stat -c '%s' "/lscratch/${SLURM_JOBID}/${dstack}" ";" else echo 0 ";" fi)
		echo node ${i}: copied ${currsize} of ${orisize}
		count=$(( count+1 ))

		# If it is not copying anything for ~100 secconds, use the rest of the files from the Particles/Micrographs directory
		if [ "$count" -gt 20 ]; then
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

else

# Modify the star file to indicate that the stack should be read from local /lscratch

cp ${starfile} ${starfile}.save

cat ${starfile} | perl -pe "s|/lscratch/.*?/|/lscratch/${SLURM_JOBID}/|g" > ${starfile}.mod
cat ${starfile}.mod | sed "s|Particles/${m}/|/lscratch/${SLURM_JOBID}/|" > ${starfile}
rm ${starfile}.mod

echo finished modifying star file to use /lscratch/$SLURM_JOBID/

echo started copying files at $(date)


filled=0

while read dstack
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
			# This wait value should be set to something bigger if each file is larger than 5 GB, as checking file sizes very often could slow the copying process.
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
done < <(for p in `awk -v c=${col[1]} '{if (NF<= 2) {} else {print $c}}' ${starfile}`; do echo ${p##*/}; done | uniq)
fi

echo finsihed copying files at $(date)
echo "All stacks transferred to /lscratch/$SLURM_JOBID"

# run relion
srun --mpi=pmi2 $command

