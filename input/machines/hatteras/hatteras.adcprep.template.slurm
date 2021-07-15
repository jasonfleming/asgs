#!/bin/bash
#
#----------------------------------------------------------------------------
#                    S L U R M   D I R E C T I V E S
#----------------------------------------------------------------------------
#SBATCH -J %jobtype%.%enstorm%
#SBATCH -t %wallminutes%
#SBATCH -n 1 
#SBATCH --partition=%partition%
#SBATCH --reservation=%reservation%
#SBATCH --constraint=%constraint%
#SBATCH -o %advisdir%/%enstorm%/%jobtype%.%enstorm%.out
#
#----------------------------------------------------------------------------
#        L O G   M E S S A G E S   T O   S T A R T   T H E   J O B
#----------------------------------------------------------------------------
DATETIME=`date +'%Y-%h-%d-T%H:%M:%S%z'`
echo "[${DATETIME}] INFO: adcprep.%jobtype%.slurm: Executing %jobtype%.%enstorm% in %advisdir%/%enstorm% with SLURM Job ID ${SLURM_JOBID}; SLURM submit directory ${SLURM_SUBMIT_DIR}; and SLURM submit host ${SLURM_SUBMIT_HOST}." | tee --append %syslog% %jobtype%.%enstorm%.run.start
echo "time.%jobtype%.${SLURM_JOBID}.start : $DATETIME" >> run.properties
#
hostname | tee CONTROL.TXT
echo "Job Run on Nodes"  | tee --append CONTROL.TXT
echo "----------------"  | tee --append CONTROL.TXT
echo $SLURM_JOB_NODELIST | tee --append CONTROL.TXT
echo "----------------"  | tee --append CONTROL.TXT
echo "hpc.slurm.job.%jobtype%.${SLURM_JOBID}.slurm_job_nodelist : $SLURM_JOB_NODELIST" >> run.properties
#
# log the command used to run adcprep
CMD="srun %adcircdir%/adcprep --np %ncpu% --%jobtype% --strict-boundaries"
DATETIME=`date +'%Y-%h-%d-T%H:%M:%S%z'`
echo "[${DATETIME}] INFO: adcprep.%jobtype%.slurm: Executing %jobtype%.%enstorm% with the command $CMD" | tee --append %syslog% 
#
#----------------------------------------------------------------------------
#                      L O A D   M O D U L E S
#----------------------------------------------------------------------------
module purge
export MODULEPATH=$MODULEPATH:/projects/acis/modules/modulefiles
module load intelc/18.0.0 intelfort/18.0.0
module load hdf5/1.8.12-acis
module load netcdf/4.2.1.1-acis
module load netcdf-Fortran/4.2-acis
module load mvapich2/2.0-acis
#export MV2_DEBUG_SHOW_BACKTRACE=2
#
#----------------------------------------------------------------------------
#                  E X E C U T E   T H E   J O B
#----------------------------------------------------------------------------
cd %advisdir%/%enstorm%
$CMD 2>&1
ERROVALUE=$?
# 
#----------------------------------------------------------------------------
#           C H E C K   S T A T U S   O F   R E S U L T S
#----------------------------------------------------------------------------
# FIXME: insert code to detect failures in adcprep that still allow it to 
# finish with a normal exit code
if [ $ERROVALUE == 0 ] ; then
   RUNSUFFIX="finish"
else
   RUNSUFFIX="error"
fi
DATETIME=`date +'%Y-%h-%d-T%H:%M:%S%z'`
echo "[${DATETIME}] INFO: adcprep.%jobtype%.slurm: Finished in %advisdir%/%enstorm% with return value = $ERROVALUE" | tee --append %jobtype%.%enstorm%.run.${RUNSUFFIX}
echo "time.%jobtype%.${SLURM_JOBID}.${RUNSUFFIX} : $DATETIME" >> run.properties
