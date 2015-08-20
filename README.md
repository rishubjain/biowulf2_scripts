# biowulf2_scripts
For running RELION on the biowulf2 servers at NIH.

The sbatch_new_lscratch_rel14.sh script copies the particle stack listed in the input star file to the /lscratch/ directory.

The sbatch_simple.sh script changes any star filenames from /lscratch/ to Particles/Micrographs/, and sets all the biowulf2 parameters.

The sbatch.bash script is the default script for running RELION.
