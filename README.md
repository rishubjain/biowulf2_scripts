# biowulf2_scripts

During my summer internship at the NIH, I wrote these scripts to run RELION on NIH's biowulf2 servers. Simple scripts already existed for the biowulf1 servers, but many things changed in biowulf2 and these scripts account for that. Also, I implemented many new features, as written in the comments.

**File Explanations:**

The sbatch_new_lscratch_rel14.sh script copies the particle stack listed in the input star file to the /lscratch/ directory.

I recently added to sbatch_new_lscratch_rel14.sh, so there might be some obscure bugs I have not tested. If it is not working, you can use the old one, sbatch_new_lscratch_rel14_2.sh, which is a well tested working version with less features (as listed in the comments).

The sbatch_simple.sh script changes any star filenames from /lscratch/ to Particles/Micrographs/, and sets all the biowulf2 parameters.

The sbatch.bash script is the default script for running RELION.
