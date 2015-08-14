#!/bin/bash
#SBATCH -t 10:00:00
#SBATCH -N 1

# Differences between vliegtuig and cartesius ->
#    - srun (cartesius) / mpirun (vliegtuig)
#    - ...

cd ${HOME}/Projects/I-EMIC/rundir_profile

# specify horizontal grid size
k=64
fname=profile_${k}x${k}
echo writing to $fname
echo $k x $k >> $fname
sed -i "s/Global Grid-Size n.*value.*/Global Grid-Size n\" type=\"int\" value=\"$k\"\/>/" \
	ocean_params.xml
sed -i "s/Global Grid-Size m.*value.*/Global Grid-Size m\" type=\"int\" value=\"$k\"\/>/" \
	ocean_params.xml

procs=1
echo "Profile on:" ${PLAT} " in:" ${PWD} > $fname

# 1,2,4,8,16 procs
for i in {1..5}
do
	echo "----------------------------------------------------------\
----------------------------------" >> $fname
    echo "Run:   " $i >> $fname 
	echo "#Procs:" $procs >> $fname
	mpirun -n $procs ./test > dump
	cat profile_output >> $fname
	procs=$(($procs*2))
done