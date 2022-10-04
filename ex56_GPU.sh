#!/bin/bash
#PBS -A <project_code>
#PBS -j oe
#PBS -l walltime=00:30:00
#PBS -l select=1:ncpus=4:mpiprocs=4:ompthreads=1:mem=100G:ngpus=4:gpu_model=v100

### Set temp to scratch
[ -d /glade/scratch/${USER} ] && export TMPDIR=/glade/scratch/${USER}/tmp && mkdir -p $TMPDIR

. config_env.sh || exit 1

# force a specific runtime environment
# module purge
# module load crayenv
# module load PrgEnv-gnu/8.3.2 craype-x86-rome craype-accel-nvidia80 libfabric cray-pals cpe-cuda
# module list

### Interrogate Environment
env | sort | uniq | egrep -v "_LM|_ModuleTable|Modules|lmod_sh"

cd ${PETSC_DIR}/src/snes/tutorials || exit 1
make ex56

[ -x ./ex56 ] || { echo "cannot find tests: ex56"; exit 1; }

ps auxww | grep "nvidia-cuda-mps-control"
nvidia-smi -a > "nvidia-smi_a-${PBS_JOBID}.txt"
nvidia-smi

status="SUCCESS"

echo "------------------------------------------------"
echo " ex56:"
echo "------------------------------------------------"
ldd ex56

echo && echo && echo "********* Intra-Node (GPU) *****************"
mpiexec -n 4 ${top_dir}/get_local_rank \
    ./ex56 -ex56_dm_mat_type aijcusparse -ex56_dm_vec_type cuda -log_view \
    || status="FAIL"

mpiexec -n 4 ${top_dir}/get_local_rank \
    ./ex56 -ex56_dm_mat_type aijviennacl -ex56_dm_vec_type viennacl -log_view \
    || status="FAIL"

echo && echo && echo
echo "${status}: Done at $(date)"
