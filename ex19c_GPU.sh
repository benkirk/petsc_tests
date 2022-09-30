#!/bin/bash
#PBS -A <project_code>
#PBS -j oe
#PBS -l walltime=00:30:00
#PBS -l select=4:ncpus=4:mpiprocs=4:ompthreads=1:mem=100G:ngpus=4:gpu_model=v100

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
make ex19

[ -x ./ex19 ] || { echo "cannot find tests: ex19"; exit 1; }

ps auxww | grep "nvidia-cuda-mps-control"
nvidia-smi -a > "nvidia-smi_a-${PBS_JOBID}.txt"
nvidia-smi

status="SUCCESS"

echo "------------------------------------------------"
echo " ex19:"
echo "------------------------------------------------"
ldd ex19

echo && echo && echo "********* Intra-Node (GPU) *****************"
mpiexec -n 4 ${top_dir}/get_local_rank \
        ./ex19 -cuda_view -snes_monitor -pc_type mg -dm_mat_type aijcusparse -dm_vec_type cuda -da_refine 10 -snes_view -pc_mg_levels 9 -mg_levels_ksp_type chebyshev -mg_levels_pc_type jacobi -log_view \
    || status="FAIL"

echo && echo && echo "********* Inter-Node (x2) (GPU) *****************"
mpiexec -n 8 ${top_dir}/get_local_rank \
        ./ex19 -cuda_view -snes_monitor -pc_type mg -dm_mat_type aijcusparse -dm_vec_type cuda -da_refine 10 -snes_view -pc_mg_levels 9 -mg_levels_ksp_type chebyshev -mg_levels_pc_type jacobi -log_view \
    || status="FAIL"

echo && echo && echo "********* Inter-Node (x4) (GPU) *****************"
mpiexec -n 32 ${top_dir}/get_local_rank \
        ./ex19 -cuda_view -snes_monitor -pc_type mg -dm_mat_type aijcusparse -dm_vec_type cuda -da_refine 10 -snes_view -pc_mg_levels 9 -mg_levels_ksp_type chebyshev -mg_levels_pc_type jacobi -log_view \
    || status="FAIL"

echo && echo && echo
echo "${status}: Done at $(date)"
