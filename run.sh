#!/bin/bash

usage="Usage: bash $0 <job_name> <partition> <n_gpus> <command>"

n_args=$#
if [ $n_args -lt 3 ]; then
    echo "Error: Invalid arguments"
    echo $usage
    exit 1
fi

job_name=$1
partition=$2
n_gpus=$3
shift 3
command=$@


_sbatch_shebang=$(cat <<'EOF'
#!/bin/bash

EOF
)

_sbatch_jobname="#SBATCH --job-name=$job_name"
_sbatch_joboutput="#SBATCH --output=/home/yehok117/slurm_log/out/$job_name.%A.out"
_sbatch_joberror="#SBATCH --error=/home/yehok117/slurm_log/err/$job_name.%A.err"


if [ "$partition" == "hpgpu" ]; then
    _sbatch_partition="#SBATCH --partition=A100-40GB,4A100,A100-80GB"
elif [ "$partition" == "normal" ]; then
    _sbatch_partition="#SBATCH --partition=A100-pci,RTX6000ADA,L40S,A6000"
elif [ "$partition" == "low" ]; then
    _sbatch_partition="#SBATCH --partition=RTX6000ADA,L40S,A6000,3090"
else
    _sbatch_partition="#SBATCH --partition=$partition"
fi

if [[ "$partition" == *"A100-40GB"* || "$partition" == *"4A100"* || "$partition" == *"A100-80GB"* ]]; then
    _sbatch_qos="#SBATCH --qos=hpgpu"
else
    _sbatch_qos=""
fi

_sbatch_gres="#SBATCH --gres=gpu:$n_gpus"

_sbatch_prefix=$(cat <<'EOF'
#SBATCH --time=3-00:00:00
#SBATCH --nodes=1
#SBATCH --exclude=n48
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8

cd $SLURM_SUBMIT_DIR
echo "SLURM_JOB_NAME=$SLURM_JOB_NAME"
echo "SLURM_JOB_ID=$SLURM_JOB_ID"
echo "SLURM_SUBMIT_DIR=$SLURM_SUBMIT_DIR"

echo "HOSTNAME: $(hostname)"
echo "DATE: $(date)"

echo "%%%%%%%%%%%% GPU INFO %%%%%%%%%%%%"
echo "CUDA_HOME=$CUDA_HOME"
echo "CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES"
echo "CUDA_VERSION=$CUDA_VERSION"

nvidia-smi
nvidia-smi -L

echo "%%%%%%%%%%%% ENVIRONMENT %%%%%%%%%%%%"
source ~/.conda_init.sh
conda activate topk-py39
which python

EOF
)

execution="$command"

export SLURM_EXEC_COMMAND="$execution"
start="bash /home/yehok117/slurm/start.sh \$SLURM_JOB_ID \$SLURM_JOB_NAME \$SLURM_JOB_PARTITION"
done="bash /home/yehok117/slurm/done.sh \$SLURM_JOB_ID \$SLURM_JOB_NAME \$SLURM_JOB_PARTITION \$?"

script_path=$(mktemp)
echo "$_sbatch_shebang" > $script_path
echo "$_sbatch_jobname" >> $script_path
echo "$_sbatch_joboutput" >> $script_path
echo "$_sbatch_joberror" >> $script_path
echo "$_sbatch_partition" >> $script_path
echo "$_sbatch_qos" >> $script_path
echo "$_sbatch_gres" >> $script_path
echo "$_sbatch_prefix" >> $script_path

echo "$start" >> $script_path
echo "$execution" >> $script_path
echo "$done" >> $script_path

echo "Executing the following sbatch script:"
cat $script_path
sbatch $script_path
