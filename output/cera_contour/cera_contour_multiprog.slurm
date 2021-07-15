#!/bin/bash
#
#----------------------------------------------------------------------------
#                    S L U R M   D I R E C T I V E S
#----------------------------------------------------------------------------
#SBATCH -J cera_contour
#SBATCH -t 20
#SBATCH -n 84
#SBATCH --partition=ncfs
#SBATCH --reservation=ncfs
#SBATCH -o /projects/ncfs/data/tests/cera_contour/cera_contour.out
#
#----------------------------------------------------------------------------
#        L O G   M E S S A G E S   T O   S T A R T   T H E   J O B
#----------------------------------------------------------------------------
DATETIME=`date +'%Y-%h-%d-T%H:%M:%S'`
echo "[${DATETIME}] INFO: SLURM Job ID ${SLURM_JOBID}; SLURM submit directory ${SLURM_SUBMIT_DIR}; and SLURM submit host ${SLURM_SUBMIT_HOST}." 
#
hostname | tee CONTROL.TXT
echo "Job Run on Nodes"  | tee --append CONTROL.TXT
echo "----------------"  | tee --append CONTROL.TXT
echo $SLURM_JOB_NODELIST | tee --append CONTROL.TXT
echo "----------------"  | tee --append CONTROL.TXT
#
#----------------------------------------------------------------------------
#                      L O A D   M O D U L E S
#----------------------------------------------------------------------------
module load intelc/14.0.3  
module load intelfort/14.0.3
module load netcdf/4.1.3_intel-14.0.3
module load mvapich2/2.0_intel-14.0.3_ch3_ofed-3.1  
# for cera_contour.py
module load gdal/1.11.1_gcc
source /projects/ncfs/apps/kalpana/env/bin/activate
# 
#----------------------------------------------------------------------------
#                  E X E C U T E   T H E   J O B
#----------------------------------------------------------------------------
cd /projects/ncfs/data/tests/cera_contour
#
# log the command used to run the job
DATETIME=`date +'%Y-%h-%d-T%H:%M:%S'`
CMD="srun -n 84 -l --multi-prog wind_shape.conf"
echo "[${DATETIME}] INFO: Executing cera_contour with the command $CMD" 
$CMD 
#
DATETIME=`date +'%Y-%h-%d-T%H:%M:%S'`
CMD="srun -n 84 -l --multi-prog elev_shape.conf"
echo "[${DATETIME}] INFO: Executing cera_contour with the command $CMD" 
$CMD
ERROVALUE=$?  # capture exit status
# 
#----------------------------------------------------------------------------
#           C H E C K   S T A T U S   O F   R E S U L T S
#----------------------------------------------------------------------------
ERROMSG=""
#
if [ $ERROVALUE == 0 ] ; then
   RUNSUFFIX="finish"
else
   RUNSUFFIX="error"
fi
DATETIME=`date +'%Y-%h-%d-T%H:%M:%S'`
echo "[${DATETIME}] INFO: cera_contour.py finished in /projects/ncfs/data/tests/cera_contour with return value = $ERROVALUE" 
#
#  write reason for job failure
DATETIME=`date +'%Y-%h-%d-T%H:%M:%S'`
if [ $ERROVALUE == 1 ]; then
   echo "[${DATETIME}] ERROR: $ERROMSG" 
fi
