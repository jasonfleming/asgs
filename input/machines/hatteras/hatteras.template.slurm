#!/bin/bash
#
#----------------------------------------------------------------------------
#                    S L U R M   D I R E C T I V E S
#----------------------------------------------------------------------------
#SBATCH -J %jobtype%.%enstorm%
#SBATCH -t %wallminutes%
#SBATCH -n %ncpu% 
#SBATCH --partition=%partition%
#SBATCH --reservation=%reservation%
#SBATCH --constraint=%constraint%
#SBATCH -o %advisdir%/%enstorm%/%jobtype%.%enstorm%.out
#
#----------------------------------------------------------------------------
#        L O G   M E S S A G E S   T O   S T A R T   T H E   J O B
#----------------------------------------------------------------------------
cd %advisdir%/%enstorm%
#
LOGFILE="fort.68.debug"
echo -n "MD5SUM: "
md5sum fort.68.nc >> $LOGFILE
echo "STAT:"
echo "-----------------------"
stat fort.68.nc >> $LOGFILE
echo "-----------------------"
#
DATETIME=`date +'%Y-%h-%d-T%H:%M:%S%z'`
echo "[${DATETIME}] INFO: %jobtype%.slurm: Executing %jobtype%.%enstorm% in %advisdir%/%enstorm% with SLURM Job ID ${SLURM_JOBID}; SLURM submit directory ${SLURM_SUBMIT_DIR}; and SLURM submit host ${SLURM_SUBMIT_HOST}." | tee --append %syslog% %jobtype%.%enstorm%.run.start
echo "time.%jobtype%.${SLURM_JOBID}.start : $DATETIME" >> run.properties
#
hostname | tee CONTROL.TXT
echo "Job Run on Nodes"  | tee --append CONTROL.TXT
echo "----------------"  | tee --append CONTROL.TXT
echo $SLURM_JOB_NODELIST | tee --append CONTROL.TXT
echo "----------------"  | tee --append CONTROL.TXT
echo "hpc.slurm.job.%jobtype%.${SLURM_JOBID}.slurm_job_nodelist : $SLURM_JOB_NODELIST" >> run.properties
#
# log the command used to run the job
CMD="srun %adcircdir%/%jobtype% %cloptions%"
DATETIME=`date +'%Y-%h-%d-T%H:%M:%S%z'`
echo "[${DATETIME}] INFO: %jobtype%.slurm: Executing %jobtype%.%enstorm%
 with the command $CMD" | tee --append %syslog% %jobtype%.%enstorm%.run.start
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
#----------------------------------------------------------------------------
#                  E X E C U T E   T H E   J O B
#----------------------------------------------------------------------------
ERROMSG=""
$CMD 
ERROVALUE=$?  # capture exit status
# 
#----------------------------------------------------------------------------
#           C H E C K   S T A T U S   O F   R E S U L T S
#----------------------------------------------------------------------------
if [ $ERROVALUE = 0 ] ; then
   for file in adcirc.log %advisdir%/%enstorm%/%jobtype%.%enstorm%.out ; do
      if [ -e $file ]; then
         # look for numerical instability errors in the stdout/stderr files
         numMsg=`grep WarnElev $file | wc -l`
         if [ $numMsg = 0 ]; then
            DATETIME=`date +'%Y-%h-%d-T%H:%M:%S%z'`
            echo "[${DATETIME}] INFO: %jobtype%.slurm: No numerical instability detected in $file after executing %jobtype%.%enstorm%." | tee --append %syslog%
         else
            ERROMSG="$ERROMSG Detected $numMsg numerical instability messages in $file."
            ERROVALUE=1
         fi
         # look for other indications of errors
         numMsgKilled=`grep Killed $file | wc -l`
         numMsgAbort=`grep MPI_Abort | wc -l`
         numMsg=`expr $numMsgKilled + $numMsgAbort`
         if [ $numMsg = 0 ]; then
            DATETIME=`date +'%Y-%h-%d-T%H:%M:%S%z'`
            echo "[${DATETIME}] INFO: %jobtype%.slurm: No egregious error messages detected in $file after executing %jobtype%.%enstorm%." | tee --append %syslog%
         else
            ERROMSG="$ERROMSG Detected $numMsg 'Killed' or 'MPI_Abort' messages in $file."
            ERROVALUE=1
         fi
      fi
   done
else
   ERROMSG="The %jobtype%.%enstorm% job ended with an exit status that indicates an error occurred."
fi
#
if [ $ERROVALUE = 0 ] ; then
   RUNSUFFIX="finish"
else
   RUNSUFFIX="error"
fi
DATETIME=`date +'%Y-%h-%d-T%H:%M:%S%z'`
echo "[${DATETIME}] INFO: %jobtype%.slurm: %jobtype%.%enstorm% finished in %advisdir%/%enstorm% with return value = $ERROVALUE" | tee --append %jobtype%.%enstorm%.run.${RUNSUFFIX}
#
#  write reason for job failure
DATETIME=`date +'%Y-%h-%d-T%H:%M:%S%z'`
if [ $ERROVALUE == 1 ]; then
   echo "[${DATETIME}] ERROR: %jobtype%.slurm: $ERROMSG" | tee --append %syslog% %jobtype%.%enstorm%.run.${RUNSUFFIX}
fi
echo "time.%jobtype%.${SLURM_JOBID}.${RUNSUFFIX} : $DATETIME" >> run.properties
