# biowulf2_scripts
For running RELION on the biowulf2 servers at NIH.

The sbatch_new_lscratch_rel14.sh script copies the particle stack listed in the input star file to the /lscratch/ directory.

I recently added stuff to sbatch_new_lscratch_rel14.sh, so there might be some obscure bugs I have not tested. If it is not working, you can use the old one, sbatch_new_lscratch_rel14_2.sh, which is a well tested working version with less features.

The sbatch_simple.sh script changes any star filenames from /lscratch/ to Particles/Micrographs/, and sets all the biowulf2 parameters.

The sbatch.bash script is the default script for running RELION.
