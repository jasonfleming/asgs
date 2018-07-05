#!/bin/bash
#----------------------------------------------------------------
#
# asgs_main.sh: This is the main driver script for the ADCIRC Surge Guidance
# System (ASGS). It performs configuration tasks via config.sh, then enters a
# loop which is executed once per advisory cycle.
#
#----------------------------------------------------------------
# Copyright(C) 2006--2016 Jason Fleming
# Copyright(C) 2006, 2007 Brett Estrade
#
# This file is part of the ADCIRC Surge Guidance System (ASGS).
#
# The ASGS is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ASGS is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with the ASGS.  If not, see <http://www.gnu.org/licenses/>.
#----------------------------------------------------------------
#
#####################################################################
#                B E G I N   F U N C T I O N S
#####################################################################
#
echoHelp()
{ clear
  echo "@@@ Help @@@"
  echo "Usage:"
  echo " bash %$0 [-s /full/path/to/statefile] [-c /fullpath/of/asgs_config.sh] -e environment"
  echo
  echo "Options:"
  echo "-c : set location of configuration file"
  echo "-e (environment): set the computer that the ASGS is running on"
  echo "-s : start from a previous statefile (used when started by cron)"
  echo "-h : show help"
  exit;
}
#
# subroutine to check for the existence of required files that have
# been specified in config.sh
checkFileExistence()
{ FPATH=$1
  FTYPE=$2
  FNAME=$3
  THIS="asgs_main.sh>checkFileExistence()"
  if [[ -z $FNAME ]]; then
     fatal "$THIS: The $FTYPE was not specified in the configuration file. When it is specified, the ASGS will look for it in the path ${FPATH}."
     RMQMessage "EXIT" "$CURRENT_EVENT" "$THIS" "FAIL" "The $FTYPE was not specified in the configuration file. When it is specified, the ASGS will look for it in the path ${FPATH}."
  fi
  if [ $FNAME ]; then
     if [ -e "${FPATH}/${FNAME}" ]; then
        logMessage "$THIS: The $FTYPE '${FPATH}/${FNAME}' was found."
     else
        RMQMessage "EXIT" "$CURRENT_EVENT" "$THIS" "FAIL" "The $FTYPE '${FPATH}/${FNAME}' does not exist."
        fatal "$THIS: The $FTYPE '${FPATH}/${FNAME}' does not exist."
     fi
  fi
}
#
# compare the modification times of the input files with the archive of
# subdomain files to avoid using a stale archive
checkArchiveFreshness()
{  PREPPEDARCHIVE=$1
   HINDCASTARCHIVE=$2
   GRIDFILE=$3
   CONTROLTEMPLATE=$4
   ELEVSTATIONS=$5
   VELSTATIONS=$6
   METSTATIONS=$7
   NAFILE=$8
   INPUTDIR=$9
   THIS="asgs_main.sh>checkArchiveFreshness()" 

   RMQMessage "INFO" "$CURRENT_EVENT" "$THIS" "$CURRENT_STATE"  "Checking to see if the archive of preprocessed subdomain files is up to date." 
   logMessage "$THIS: Checking to see if the archive of preprocessed subdomain files is up to date."   
   for archiveFile in $PREPPEDARCHIVE $HINDCASTARCHIVE; do
      if [ ! -e $INPUTDIR/$archiveFile ]; then
         logMessage "$THIS: The subdomain archive file $INPUTDIR/$archiveFile does not exist."
         continue
      fi
      for inputFile in $GRIDFILE $CONTROLTEMPLATE $ELEVSTATIONS $VELSTATIONS $METSTATIONS $NAFILE; do
         if [ ! -e $INPUTDIR/$inputFile ]; then
            RMQMessage "WARN" "$CURRENT_EVENT" "$THIS" "WARN" "The input file $INPUTDIR/$inputFile does not exist."
            warn "$THIS: The input file $INPUTDIR/$inputFile does not exist."
            continue
         fi
         # see if the archiveFile is older than inputFile 
         if [ $INPUTDIR/$archiveFile -ot $INPUTDIR/$inputFile ]; then 
            logMessage "$THIS: A change in the input files has been detected. The archive file $archiveFile is older than the last modification time of the input file ${inputFile}. The archive file is therefore stale and will be deleted. A fresh one will automatically be created the next time adcprep is run." 
            rm $INPUTDIR/$archiveFile 2>> $SYSLOG 
            break
         fi
      done
   done
}
#
# subroutine to check for the existence of required directories
# that have been specified in config.sh
checkDirExistence()
{ DIR=$1
  TYPE=$2
  THIS="asgs_main.sh>checkDirExistence()"
  if [[ -z $DIR ]]; then
     RMQMessage "EXIT" "$CURRENT_EVENT" "$THIS" "FAIL" "The $TYPE was not specified in the configuration file."
     fatal "$THIS: The $TYPE was not specified in the configuration file."
  fi
  if [ -e $DIR ]; then
     logMessage "$THIS: The $TYPE '$DIR' was found."
  else
     RMQMessage "FAIL" "$CURRENT_EVENT" "$THIS" "FAIL" "The $TYPE $DIR does not exist."
     fatal "$THIS: The $TYPE '$DIR' does not exist."
  fi
}
#
# subroutine to check for the existence and nonzero length of the
# hotstart file
# the subroutine assumes that the hotstart file is named fort.$LUN or
# fort.$LUN.nc depending on the format and expects it to be provided with
# the full path if it is not in the current directory.
checkHotstart()
{
   FROMDIR=$1
   HOTSTARTFORMAT=$2
   LUN=$3
#
   THIS="asgs_main.sh>checkHotstart()"
   HOTSTARTFILE=''
   # set name and specific file location based on format (netcdf or binary)
   if [[ $HOTSTARTFORMAT = netcdf ]]; then
      HOTSTARTFILE=$FROMDIR/fort.$LUN.nc
   else
      HOTSTARTFILE=$FROMDIR/PE0000/fort.$LUN
   fi
   # check for existence of hotstart file
   if [ ! -e $HOTSTARTFILE ]; then
      RMQMessage "FAIL" "$CURRENT_EVENT" "$THIS" "FAIL" "The hotstart file '$HOTSTARTFILE' was not found. The preceding simulation run must have failed to produce it."
      fatal "$THIS: The hotstart file '$HOTSTARTFILE' was not found. The preceding simulation run must have failed to produce it."
   # if it exists, check size to be sure its nonzero
   else
      hotstartSize=`stat -c %s $HOTSTARTFILE`
      if [ $hotstartSize == "0" ]; then
         RMQMessage "FAIL" "$CURRENT_EVENT" "$THIS" "FAIL" "The hotstart file $HOTSTARTFILE is of zero length. The preceding simulation run must have failed to produce it."
         fatal "$THIS: The hotstart file '$HOTSTARTFILE' is of zero length. The preceding simulation run must have failed to produce it properly."
      else
         RMQMessage "INFO" "$CURRENT_EVENT" "$THIS" "$CURRENT_STATE" "The hotstart file '$HOTSTARTFILE' was found and it contains $hotstartSize bytes."
         logMessage "$THIS: The hotstart file '$HOTSTARTFILE' was found and it contains $hotstartSize bytes."
         # check time in hotstart file to be sure it can be found and that
         # it is nonzero
         # jgf20170131: hstime reports errors to stderr so we must capture
         # that with backticks and tee to the log file
         HSTIME=''
         if [[ $HOTSTARTFORMAT = netcdf ]]; then
            HSTIME=`$ADCIRCDIR/hstime -f $HOTSTARTFILE -n 2>&1 | tee --append ${SYSLOG}`
         else
            HSTIME=`$ADCIRCDIR/hstime -f $HOTSTARTFILE 2>&1 | tee --append ${SYSLOG}`
         fi
         failureOccurred=$?
         errorOccurred=`expr index "$HSTIME" ERROR`
         if [[ $failureOccurred != 0 || $errorOccurred != 0 ]]; then
            fatal "$THIS: The hstime utility could not read the ADCIRC time from the file '$HOTSTARTFILE'. The output from hstime was as follows: '$HSTIME'."
         else
            if float_cond '$HSTIME == 0.0'; then
               THIS="asgs_main.sh>checkHotstart()"
               fatal "$THIS: The time in the hotstart file '$HOTSTARTFILE' is zero. The preceding simulation run must have failed to produce a proper hotstart file."
            fi
         fi
      fi
   fi
}
#
# Evaluate a floating point number conditional expression.
# From http://www.linuxjournal.com/content/floating-point-math-bash
function float_cond()
{
    THIS="asgs_main.sh>float_cond()"
    local cond=0
    if [[ $# -gt 0 ]]; then
        cond=$(echo "$*" | bc -q 2>/dev/null)
        if [[ -z "$cond" ]]; then cond=0; fi
        if [[ "$cond" != 0  &&  "$cond" != 1 ]]; then cond=0; fi
    fi
    local stat=$((cond == 0))
    return $stat
}
#
# subroutine to run adcprep, using a pre-prepped archive of fort.13,
# fort.14 and fort.18 files
prep()
{   ADVISDIR=$1  # directory containing the now/forecast runs for this cycle
    INPUTDIR=$2 # directory where grid and nodal attribute files are found
    ENSTORM=$3  # ensemble member (nowcast, storm1, storm5, etc)
    START=$4    # coldstart or hotstart
    FROMDIR=$5 # directory containing files to hotstart this run from 
    ENV=$6     # machine to run on (jade, desktop, queenbee, etc)
    NCPU=$7     # number of CPUs to request in parallel jobs
    PREPPEDARCHIVE=$8 # preprocessed fort.13 and fort.14 package
    GRIDFILE=$9 # fulldomain grid
    ACCOUNT=${10} # account to charge time to
    OUTPUTOPTIONS="${11}" # contains list of args for appending files
    HOTSTARTCOMP=${12} # fulldomain or subdomain
    WALLTIME=${13} # HH:MM:SS format
    HOTSTARTFORMAT=${14}   # "binary" or "netcdf"
    MINMAX=${15}           # "continuous" or "reset"
    HOTSWAN=${16} # "yes" or "no" to reinitialize SWAN only
    NAFILE=${17}  # full domain nodal attributes file, must be last in the
                  # argument list, since it may be undefined
    TIMESTAMP=`date +%d%b%Y:%H:%M:%S`
    THIS="asgs_main.sh>prep()"
#
    # set the name of the archive of preprocessed input files
    PREPPED=$PREPPEDARCHIVE
    if [[ $START = coldstart ]]; then
       PREPPED=$HINDCASTARCHIVE
    fi
    # determine if there is an archive of preprocessed input files
    HAVEARCHIVE=yes
    if [[ ! -e ${INPUTDIR}/${PREPPED} ]]; then
       HAVEARCHIVE=no
    fi
    # create directory to run in 
    if [ ! -d $ADVISDIR/$ENSTORM ]; then
      mkdir $ADVISDIR/$ENSTORM 2>> ${SYSLOG}
    fi
    echo "$TIMESTAMP INFO: $ENSTORM: $THIS: adcprep.log entry for $FILE for ensemble member $ENSTORM in $ADVISDIR as follows: " >> $ADVISDIR/$ENSTORM/adcprep.log
    cd $ADVISDIR/$ENSTORM
    logMessage "Linking to full domain input files."
    # symbolically link grid
    if [ ! -e $ADVISDIR/$ENSTORM/fort.14 ]; then
        ln -s $INPUTDIR/$GRIDFILE $ADVISDIR/$ENSTORM/fort.14 2>> ${SYSLOG}
    fi
    # symbolically link nodal attributes
    if [ ! -e $ADVISDIR/$ENSTORM/fort.13 ]; then
        if [[ ! -z $NAFILE  && $NAFILE != null ]]; then
           ln -s $INPUTDIR/$NAFILE $ADVISDIR/$ENSTORM/fort.13 2>> ${SYSLOG}
        fi
    fi
    if [[ $HAVEARCHIVE = yes ]]; then
        # copy in the files that have already been preprocessed
        logMessage "$ENSTORM: $THIS: Copying input files that have already been decomposed."
        cp $INPUTDIR/${PREPPED} . 2>> ${SYSLOG}
        gunzip -f ${PREPPED} 2>> ${SYSLOG}
        # untar the uncompressed archive
        UNCOMPRESSEDARCHIVE=${PREPPED%.gz}
        tar xvf $UNCOMPRESSEDARCHIVE > untarred_files.log 2>> ${SYSLOG}
        logMessage "$ENSTORM: $THIS: Removing $UNCOMPRESSEDARCHIVE"
        rm $UNCOMPRESSEDARCHIVE 2>> ${SYSLOG}
    fi
    #
    # this is a C O L D S T A R T
    if [ $START = coldstart ]; then
       # if we have variable river flux, link the fort.20 and fort.88 files
       if [[ $VARFLUX = on || $VARFLUX = default ]]; then
          # jgf20110525: For now, just copy a static file to this location
          # and adcprep it. TODO: When real time flux data become available,
          # grab those instead of relying on a static file.
          ln -s ${INPUTDIR}/${HINDCASTRIVERFLUX} ./fort.20
          # run adcprep to decompose the river elevation init (fort.88) file
          ln -s ${INPUTDIR}/${RIVERINIT} ./fort.88
       fi
       # now run adcprep to decompose the files
       if [[ $HAVEARCHIVE = no ]]; then
          logMessage "$ENSTORM: $THIS: Running adcprep to partition the mesh for $NCPU compute processors."
          prepFile partmesh $NCPU $ACCOUNT $WALLTIME
          THIS="asgs_main.sh>prep()"
          logMessage "$ENSTORM: $THIS: Running adcprep to prepare all files."
          prepFile prepall $NCPU $ACCOUNT $WALLTIME
          THIS="asgs_main.sh>prep()"
       else
          logMessage "$ENSTORM: $THIS: Running adcprep to prepare new fort.15 file."
          prepFile prep15 $NCPU $ACCOUNT $WALLTIME
          THIS="asgs_main.sh>prep()"
          if [[ $VARFLUX = on || $VARFLUX = default ]]; then
             logMessage "$ENSTORM: $THIS: Running adcprep to prepare new fort.20 file."
             prepFile prep20 $NCPU $ACCOUNT $WALLTIME
             THIS="asgs_main.sh>prep()"
             logMessage "$ENSTORM: $THIS: Running adcprep to prepare fort.88 file."
             prepFile prep88 $NCPU $ACCOUNT $WALLTIME
             THIS="asgs_main.sh>prep()"
          fi
       fi
    else
       # this is a H O T S T A R T
       #
       # copy in the swaninit file which contains the name of the swan
       # control file (conventionally named fort.26 when used with ADCIRC)
       if [[ $WAVES = on ]]; then
          cp $INPUTDIR/swaninit.template $ADVISDIR/$ENSTORM/swaninit 2>> ${SYSLOG}
       fi
       # jgfdebug: TODO: FIXME: Hardcoded the time varying weirs input file 
       if [ -e $INPUTDIR/time-bonnet.in ]; then 
          logMessage "$ENSTORM: $THIS: Copying $INPUTDIR/time-bonnet.in to $ADVISDIR/$ENSTORM."
          cp $INPUTDIR/time-bonnet.in $ADVISDIR/$ENSTORM 2>> ${SYSLOG}
       fi 
       # run adcprep to decompose the new files
       if [[ $HAVEARCHIVE = no ]]; then
          logMessage "$ENSTORM: $THIS: Running adcprep to partition the mesh for $NCPU compute processors."
          prepFile partmesh $NCPU $ACCOUNT $WALLTIME
          THIS="asgs_main.sh>prep()"
          logMessage "$ENSTORM: $THIS: Running adcprep to prepare all files."
          prepFile prepall $NCPU $ACCOUNT $WALLTIME
          THIS="asgs_main.sh>prep()"
       else
          logMessage "$ENSTORM: $THIS: Running adcprep to prepare new fort.15 file."
          prepFile prep15 $NCPU $ACCOUNT $WALLTIME
          THIS="asgs_main.sh>prep()"
          if [[ $VARFLUX = on || $VARFLUX = default ]]; then
             logMessage "$ENSTORM: $THIS: Running adcprep to prepare new fort.20 file."
             prepFile prep20 $NCPU $ACCOUNT $WALLTIME
             THIS="asgs_main.sh>prep()"
          fi
          if [[ $WAVES = on ]]; then
             PE=0
             format="%04d"
             while [[ $PE -lt $NCPU ]]; do
                PESTRING=`printf "$format" $PE`
                ln -s $ADVISDIR/$ENSTORM/fort.26 $ADVISDIR/$ENSTORM/PE${PESTRING}/fort.26 2>> ${SYSLOG}
                PE=`expr $PE + 1`
             done
          fi
       fi
       logMessage "$ENSTORM: $THIS: Copying existing output files to this directory."
       if [[ $MINMAX = continuous ]]; then
          # copy max and min files so that the max values will be
          # preserved across hotstarts
          # @jasonfleming: Applying netcdf fix from @mattbilskie
          for file in maxele.63 maxwvel.63 minpr.63 maxrs.63 maxvel.63 elemaxdry.63 nodeflag.63 rising.63 tinun.63 maxele.63.nc maxinundepth.63.nc maxrs.63.nc maxvel.63.nc maxwvel.63.nc minpr.63.nc elemaxdry.63.nc nodeflag.63.nc rising.63.nc tinun.63.nc swan_*_max.*; do
             if  [ -e $FROMDIR/$file ]; then
                logMessage "$ENSTORM: $THIS: Copying $FROMDIR/$file to $ADVISDIR/$ENSTORM/$file so that its values will be preserved across the hotstart."
                cp $FROMDIR/$file $ADVISDIR/$ENSTORM/$file 2>> ${SYSLOG}
             fi
          done
       else
          logMessage "$ENSTORM: $THIS: MINMAX was set to '$MINMAX' in the ASGS config file; as a result, the maxele.63 etc files will not be from the previous run to the current run. ADCIRC will start the record of max and min values anew."
       fi
       # copy existing fulldomain files if they are supposed to be appended
       for file in fort.61 fort.62 fort.63 fort.64 fort.71 fort.72 fort.73 fort.74; do
          matcharg=--${file/./}append
          if [[ $file = "fort.71" || $file = "fort.72" ]]; then
             matcharg="--fort7172append"
          elif [[ $file = "fort.73" || $file = "fort.74" ]]; then
             matcharg="--fort7374append"
          fi
          # check the output options to see if the file is being appended
          for arg in $OUTPUTOPTIONS ; do
             if [[ $matcharg = $arg ]]; then
                # the file is being appended; check to see if it is in netcdf
                # format, nd if so, use the netcdf name
                netCDFArg=${matcharg/append/netcdf/}
                for outputArg in $OUTPUTOPTIONS ; do
                   if [[ $outputArg = $netCDFArg ]]; then
                      file=${file/./}.nc
                   fi
                done
                if [ -e $FROMDIR/$file ]; then
                   logMessage "$ENSTORM: $THIS: Copying $FROMDIR/$file to $ADVISDIR/$ENSTORM/$file so that it will be appended during the upcoming run."
                   cp $FROMDIR/$file $ADVISDIR/$ENSTORM/$file 2>> ${SYSLOG}
                fi
             fi
          done
       done
       # bring in hotstart file(s)
       if [[ $HOTSTARTCOMP = fulldomain ]]; then
          if [[ $HOTSTARTFORMAT = netcdf ]]; then
             # copy netcdf file so we overwrite the one that adcprep created
             cp --remove-destination $FROMDIR/fort.67.nc $ADVISDIR/$ENSTORM/fort.68.nc >> $SYSLOG 2>&1
          else
             ln -s $FROMDIR/PE0000/fort.67 $ADVISDIR/$ENSTORM/fort.68 >> $SYSLOG 2>&1
          fi
       fi
       # jgfdebug
       if [[ $HOTSTARTCOMP = subdomain ]]; then
          logMessage "$ENSTORM: $THIS: Starting copy of subdomain hotstart files."
          # copy the subdomain hotstart files over
          # subdomain hotstart files are always binary formatted
          PE=0
          format="%04d"
          while [ $PE -lt $NCPU ]; do
             PESTRING=`printf "$format" $PE`
             if [[ $HOTSTARTCOMP = subdomain ]]; then            
                cp $FROMDIR/PE${PESTRING}/fort.67 $ADVISDIR/$ENSTORM/PE${PESTRING}/fort.68 2>> ${SYSLOG}
             fi
             PE=`expr $PE + 1`
          done
          logMessage "$ENSTORM: $THIS: Completed copy of subdomain hotstart files."
       fi

       if [[ $WAVES = on && $HOTSWAN = on ]]; then
          # subdomain swan hotstart file
          if [[ -e $FROMDIR/PE0000/swan.67 ]]; then
             logMessage "$ENSTORM: $THIS: Starting copy of subdomain swan hotstart files."
             # copy the subdomain hotstart files over
             # subdomain hotstart files are always binary formatted
             PE=0
             format="%04d"
             while [ $PE -lt $NCPU ]; do
                PESTRING=`printf "$format" $PE`
                cp $FROMDIR/PE${PESTRING}/swan.67 $ADVISDIR/$ENSTORM/PE${PESTRING}/swan.68 2>> ${SYSLOG}
                PE=`expr $PE + 1`
             done
             logMessage "$ENSTORM: $THIS: Completed copy of subdomain hotstart files."
          else
             # fulldomain swan hotstart file or archive of subdomain
             # swan hotstart files
             if [[ -e $FROMDIR/swan.67 ]]; then
                cp $FROMDIR/swan.67 ./swan.68 2>> $SYSLOG
             fi
             if [[ -e $FROMDIR/swan.67.gz ]]; then
                cp $FROMDIR/swan.67.gz ./swan.68.gz 2>> $SYSLOG
                gunzip swan.68.gz 2>> $SYSLOG
             fi
             if [[ -e $FROMDIR/swan.67.bz2 ]]; then
                cp $FROMDIR/swan.67.bz2 ./swan.68.bz2 2>> $SYSLOG
                bunzip2 swan.68.bz2 2>> $SYSLOG
             fi
             if [[ -e $FROMDIR/swan.67.tar.gz ]]; then
                cp $FROMDIR/swan.67.tar.gz ./swan.68.tar.gz 2>> $SYSLOG
                tar xvzf swan.68.tar.gz 2>> $SYSLOG
                for dir in `ls -d PE*`; do
                   mv $dir/swan.67 $dir/swan.68 2>> $SYSLOG
                done
             fi
             if [[ -e $FROMDIR/swan.67.tar.bz2 ]]; then
                cp $FROMDIR/swan.67.tar.bz2 ./swan.68.tar.bz2 2>> $SYSLOG
                tar xvjf swan.68.tar.bz2 2>> $SYSLOG
                for dir in `ls -d PE*`; do
                   mv $dir/swan.67 $dir/swan.68 2>> $SYSLOG
                done
             fi
             if [[ -e  swan.68 ]]; then
                logMessage "$ENSTORM: $THIS: Starting decomposition of fulldomain swan hotstart file to subdomains."
                ${ADCIRCDIR}/../swan/unhcat.exe <<EOF 2>> ${SYSLOG}
2
swan.68
F
EOF
             fi
                logMessage "$ENSTORM: $THIS: Completed decomposition of fulldomain swan hotstart file."
          fi             
       fi

    fi
    # if we don't have an archive of our preprocessed files, create
    # one so that we don't have to do another prepall
    if [[ $HAVEARCHIVE = no ]]; then
       logMessage "$ENSTORM: $THIS: Creating an archive of preprocessed files and saving to ${INPUTDIR}/${PREPPED} to avoid having to run prepall again."
       FILELIST='partmesh.txt PE*/fort.14 PE*/fort.18'
       if [[ ! -z $NAFILE && $NAFILE != null ]]; then
          FILELIST='partmesh.txt PE*/fort.14 PE*/fort.18 PE*/fort.13'
       fi
       tar czf ${INPUTDIR}/${PREPPED} ${FILELIST} 2>> ${SYSLOG}
       # check status of tar operation; if it failed, delete the file
       # it attempted to make and alert the operator
       if [[ $? != 0 ]]; then
          warn "$ENSTORM: $THIS: The construction of a tar archive of the preprocessed input files has failed."
          rm ${INPUTDIR}/${PREPPED} 2>> ${SYSLOG} 2>&1
       fi
    fi
}
#
# function to run adcprep in a platform dependent way to decompose
# the fort.15, fort.20, or fort.88 file
prepFile()
{   JOBTYPE=$1
    NCPU=$2
    ACCOUNT=$3
    WALLTIME=$4
    THIS="asgs_main.sh>prepFile()"
    #
    case $QUEUESYS in
    "PBS")
       QSCRIPTOPTIONS="--jobtype $JOBTYPE --ncpu $NCPU --ppn $PPN --queuename $SERQUEUE --account $ACCOUNT --walltime $WALLTIME --adcircdir $ADCIRCDIR --advisdir $ADVISDIR --qscript $SCRIPTDIR/input/machines/$ENV/$PREPCONTROLSCRIPT --enstorm ${ENSTORM} --notifyuser $NOTIFYUSER --syslog $SYSLOG"
       RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Preparing queue script for adcprep.${JOBTYPE}.pbs"
       perl $SCRIPTDIR/$QSCRIPTGEN $QSCRIPTOPTIONS > $ADVISDIR/$ENSTORM/adcprep.${JOBTYPE}.pbs 2>> ${SYSLOG}
       # submit adcprep job, check to make sure qsub succeeded, and if not, retry
       while [ true ];  do
          qsub $ADVISDIR/$ENSTORM/adcprep.${JOBTYPE}.pbs >> ${SYSLOG} 2>&1
          if [[ $? = 0 ]]; then
             break # qsub returned a "success" status
          else
             warn "$ENSTORM: $THIS: qsub $ADVISDIR/$ENSTORM/adcprep.${JOBTYPE}.pbs failed; will retry in 60 seconds."
             sleep 60
          fi
       done
       monitorJobs $QUEUESYS ${JOBTYPE}.${ENSTORM} $WALLTIME
       THIS="asgs_main.sh>prepFile()"
       logMessage "$ENSTORM: $THIS: Finished adcprepping file ($JOBTYPE)."
       ;;
    "SLURM")
       QSCRIPTOPTIONS="--jobtype $JOBTYPE --ncpu $NCPU --ppn $PPN --queuename $SERQUEUE --account $ACCOUNT --partition $PARTITION --reservation $RESERVATION --constraint "$CONSTRAINT" --walltime $WALLTIME --adcircdir $ADCIRCDIR --advisdir $ADVISDIR --qscript $SCRIPTDIR/input/machines/$ENV/$PREPCONTROLSCRIPT --enstorm ${ENSTORM} --notifyuser $NOTIFYUSER --syslog $SYSLOG"
       #jgfdebug
       RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Preparing queue script for adcprep.${JOBTYPE}.slurm."
       logMessage "$ENSTORM: $THIS: Preparing queue script for adcprep with the following: perl $SCRIPTDIR/$QSCRIPTGEN $QSCRIPTOPTIONS > $ADVISDIR/$ENSTORM/adcprep.${JOBTYPE}.slurm 2>> ${SYSLOG}"
       perl $SCRIPTDIR/$QSCRIPTGEN $QSCRIPTOPTIONS > $ADVISDIR/$ENSTORM/adcprep.${JOBTYPE}.slurm 2>> ${SYSLOG}
       # submit adcprep job, check to make sure sbatch succeeded, and if not, retry
       while [ true ];  do
          sbatch $ADVISDIR/$ENSTORM/adcprep.${JOBTYPE}.slurm >> ${SYSLOG} 2>&1
          if [[ $? = 0 ]]; then
             break # qsub returned a "success" status
          else
             warn "$ENSTORM: $THIS: sbatch $ADVISDIR/$ENSTORM/adcprep.${JOBTYPE}.slurm failed; will retry in 60 seconds."
             sleep 60
          fi
       done
       monitorJobs $QUEUESYS ${JOBTYPE}.${ENSTORM} $WALLTIME
       THIS="asgs_main.sh>prepFile()"
       RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE"  "Finished adcprepping file ($JOBTYPE)."
       logMessage "$ENSTORM: $THIS: Finished adcprepping file ($JOBTYPE)."
       ;;
    "SGE")
       cd $ADVISDIR/$ENSTORM 2>> ${SYSLOG}
       SERQSCRIPTOPTIONS="--jobtype $JOBTYPE --ncpu $NCPU --account $ACCOUNT --adcircdir $ADCIRCDIR --walltime $WALLTIME --advisdir $ADVISDIR --enstorm $ENSTORM --notifyuser $NOTIFYUSER --serqscript $SCRIPTDIR/input/machines/$ENV/$SERQSCRIPT"
     perl $SCRIPTDIR/$SERQSCRIPTGEN $SERQSCRIPTOPTIONS > $ADVISDIR/$ENSTORM/adcprep.serial.sge 2>> ${SYSLOG}
       logMessage "$ENSTORM: $THIS: Submitting $ADVISDIR/$ENSTORM/adcprep.serial.sge."
       qsub $ADVISDIR/$ENSTORM/adcprep.serial.sge >> ${SYSLOG} 2>&1
       # if qsub succeeded, monitor the job, otherwise an error is indicated
       if [[ $? = 1 ]]; then
          rangerResubmit $ADVISDIR $ENSTORM adcprep.serial.sge $SYSLOG
          THIS="asgs_main.sh>prepFile()"
       fi
       # check once per minute until all jobs have finished
       monitorJobs $QUEUESYS ${JOBTYPE}.${ENSTORM} $WALLTIME
       THIS="asgs_main.sh>prepFile()"
       allMessage "$ENSTORM: $THIS: adcprep finished."
       ;;
    *)
       $ADCIRCDIR/adcprep --np $NCPU --${JOBTYPE} --strict-boundaries >> $ADVISDIR/$ENSTORM/${JOBTYPE}.adcprep.log 2>&1
       # check to see if adcprep completed successfully
       if [[ $? != 0 ]]; then
          error "$ENSTORM: $THIS: The adcprep ${JOBTYPE} job failed. See the file $ADVISDIR/$ENSTORM/${JOBTYPE}.adcprep.log for details."
          echo "$ENSTORM: $THIS: The adcprep ${JOBTYPE} job failed. See the file $ADVISDIR/$ENSTORM/${JOBTYPE}.adcprep.log for details." >> jobFailed
       fi
       ;;
    esac
}
#
# subroutine that calls an external script over and over until it
# pulls down a new advisory (then it returns)
downloadCycloneData()
{   STORM=$1
    YEAR=$2
    RUNDIR=$3
    SCRIPTDIR=$4
    OLDADVISDIR=$5
    TRIGGER=$6
    ADVISORY=$7
    FTPSITE=$8
    RSSSITE=$9
    FDIR=${10}
    HDIR=${11}
    STATEFILE=${12}
    THIS="asgs_main.sh>downloadCycloneData()"
#    activity_indicator "Checking remote site for new advisory..." &
    logMessage "$THIS: Checking remote site for new advisory..." 
#    pid=$!; trap "stop_activity_indicator ${pid}; exit" EXIT
    cd $RUNDIR 2>> ${SYSLOG}
    newAdvisory=false
    newAdvisoryNum=null
    forecastFileName=al${STORM}${YEAR}.fst
    hindcastFileName=bal${STORM}${YEAR}.dat
    # check to see if we have a leftover forecast.properties file from
    # a previous advisory laying around here in our run directory, and if
    # so, delete it
    if [[ -e forecast.properties ]]; then
       rm forecast.properties 2>> ${SYSLOG}
    fi
    OPTIONS="--storm $STORM --year $YEAR --ftpsite $FTPSITE --fdir $FDIR --hdir $HDIR --rsssite $RSSSITE --trigger $TRIGGER --adv $ADVISORY"
    logMessage "$THIS: Options for get_atcf.pl are as follows : $OPTIONS"
    if [ "$START" = coldstart ]; then
       RMQMessage "INFO" "$CURRENT_EVENT" "$THIS" "NONE"  "Downloading initial hindcast/forecast."
       logMessage "$THIS: Downloading initial hindcast/forecast."
    else
       RMQMessage "INFO" "$CURRENT_EVENT" "$THIS" "NONE"  "Checking remote site for new advisory..."
       logMessage "$THIS: Checking remote site for new advisory..."
    fi

echo "\$newAdvisory=$newAdvisory, \$TRIGGER=$TRIGGER"  # BOB

    while [ $newAdvisory = false ]; do
       if [[ $TRIGGER != "atcf" ]]; then 
echo Calling "get_atcf.pl $OPTIONS"  # BOB

          newAdvisoryNum=`perl $SCRIPTDIR/get_atcf.pl $OPTIONS 2>> $SYSLOG`
       fi
       # check to see if we have a new one, and if so, determine the
       # new advisory number correctly
       case $TRIGGER in
       "atcf") 
          # if the forecast is already in ATCF format, then simply copy it 
          # to the run directory
          cp $HDIR/$hindcastFileName . 2>> ${SYSLOG}
          cp $FDIR/$forecastFileName . 2>> ${SYSLOG}
          linkTarget=`readlink $FDIR/$forecastFileName`
          # assume the advisory number is the first two characters in the
          # symbolic link target of the forecast file name
          newAdvisoryNum=${linkTarget:0:2}
          if [[ $newAdvisoryNum -gt $ADVISORY ]]; then 
             newAdvisory="true" 
          else 
             newAdvisory="false" 
          fi
          ;;
       "ftp")
          if [ $START = hotstart ]; then
             if ! diff $OLDADVISDIR/$forecastFileName ./$forecastFileName > /dev/null 2>> ${SYSLOG}; then
                # forecasts from NHC ftp site do not have advisory number
                newAdvisoryNum=`printf "%02d" $[$ADVISORY + 1]`
                newAdvisory="true"
             fi
          fi
          ;;
       "rss" | "rssembedded" )
          # if there was a new advisory, the get_atcf.pl script
          # would have returned the advisory number in stdout
          if [[ ! -z $newAdvisoryNum && $newAdvisoryNum != null ]]; then
             newAdvisory="true"
             if [ -e $forecastFileName ]; then
                mv $forecastFileName $forecastFileName.ftp 2>> $SYSLOG
             fi
          fi
          ;;
       *)
          fatal "$THIS: Invalid 'TRIGGER' type: '$TRIGGER'; must be ftp, rss, rssembedded, or atcf."
          ;;
       esac
       if [ $START = coldstart ]; then
          if [ $TRIGGER = ftp ]; then
             newAdvisoryNum=$ADVISORY
          fi
          newAdvisory="true"
       fi
       if [[ $newAdvisory = false ]]; then
          sleep 60 # we are hotstarting, the advisory is same as last one
       fi
    done
    RMQMessage "INFO" "$CURRENT_EVENT" "$THIS" "$CURRENT_STATE" "New forecast detected."
    logMessage "$THIS: New forecast detected."
    cp -f $STATEFILE ${STATEFILE}.old
    sed 's/ADVISORY=.*/ADVISORY='$newAdvisoryNum'/' $STATEFILE > ${STATEFILE}.new
    cp -f ${STATEFILE}.new $STATEFILE >> ${SYSLOG} 2>&1 
    if [[ $TRIGGER = rss || $TRIGGER = rssembedded ]]; then
       perl ${SCRIPTDIR}/nhc_advisory_bot.pl --input ${forecastFileName}.html --output $forecastFileName --metadata forecast.properties >> ${SYSLOG} 2>&1
    fi
    if [[ $FTPSITE = filesystem ]]; then
       cp $HDIR/$hindcastFileName $hindcastFileName 2>> ${SYSLOG}
    fi
}
#
# subroutine that polls an external ftp site for background meteorology data,
# converts it to OWI format (reprojecting the data if necessary), makes
# symbolic links to it, and returns.
downloadBackgroundMet()
{
   RUNDIR=$1
   SCRIPTDIR=$2
   BACKSITE=$3
   BACKDIR=$4
   ENSTORM=$5
   CSDATE=$6
   HSTIME=$7
   FORECASTLENGTH=$8
   ALTNAMDIR=$9
   FORECASTCYCLE=${10}
   ARCHIVEBASE=${11}
   ARCHIVEDIR=${12}
   STATEFILE=${13}
   #
   THIS="asgs_main.sh>downloadBackgroundMet()"
   CURRENT_STATE="WAIT" 
   RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE"  "Downloading meteorological data."
   logMessage "$ENSTORM: $THIS: Downloading meteorological data."
   cd $RUNDIR 2>> ${SYSLOG}
   if [[ $ENSTORM != "nowcast" ]]; then
      grep ADVISORY $STATEFILE | sed 's/ADVISORY.*=//' | sed 's/^\s//' > currentCycle 2>> ${SYSLOG}
   fi
   newAdvisoryNum=0
   while [[ $newAdvisoryNum -lt 2 ]]; do
      OPTIONS="--rundir $RUNDIR --backsite $BACKSITE --backdir $BACKDIR --enstorm $ENSTORM --csdate $CSDATE --hstime $HSTIME --forecastlength $FORECASTLENGTH --altnamdir $ALTNAMDIR --scriptdir $SCRIPTDIR --forecastcycle $FORECASTCYCLE --archivedruns ${ARCHIVEBASE}/${ARCHIVEDIR}"
     # echo "perl ${SCRIPTDIR}/get_nam.pl $OPTIONS 2>> ${SYSLOG} "
      newAdvisoryNum=`perl ${SCRIPTDIR}/get_nam.pl $OPTIONS 2>> ${SYSLOG}` 
      if [[ $newAdvisoryNum -lt 2 ]]; then
         RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Sleeping 60 secs ..."
         sleep 60
      fi
   done
   # record the new advisory number to the statefile
   cp -f $STATEFILE ${STATEFILE}.old 2>> ${SYSLOG}
   sed 's/ADVISORY=.*/ADVISORY='$newAdvisoryNum'/' $STATEFILE > ${STATEFILE}.new
   cp -f ${STATEFILE}.new $STATEFILE >> ${SYSLOG} 2>&1          
}
#
# subroutine that downloads river flux data from an external ftp site
# and constructs a river flux boundary condition file (fort.20) to covert
# the full time period of the run
downloadRiverFluxData()
{
   ADVISDIR=$1
   MESHFILE=$2
   RIVERSITE=$3
   RIVERDIR=$4
   RIVERUSER=$5
   RIVERDATAPROTOCOL=$6
   ENSTORM=$7
   CSDATE=$8
   HSTIME=$9
   SCRIPTDIR=${10}
   DEFAULTFILE=${11}
   USERIVERFILEONLY=${12}
#
   THIS="asgs_main.sh>downloadRiverFluxData()"
   OPTIONS="--advisdir $ADVISDIR --meshfile $MESHFILE --riversite $RIVERSITE --riverdir $RIVERDIR --riveruser $RIVERUSER --riverdataprotocol $RIVERDATAPROTOCOL --enstorm $ENSTORM --csdate $CSDATE --hstime $HSTIME --scriptdir $SCRIPTDIR --defaultfile $DEFAULTFILE"
   TRIES=0
   SUCCESS=no
   if [[ $USERIVERFILEONLY = no ]]; then
      while [[ $TRIES -lt 2 ]]; do
         perl ${SCRIPTDIR}/get_flux.pl $OPTIONS 2>> ${SYSLOG}
         if [[ $? = 0 ]]; then
            logMessage "$ENSTORM: $THIS: Completed construction of river flux boundary condition (fort.20 file)."
            SUCCESS=yes
            break
         else
            TRIES=$[$TRIES + 1]
            warn "$ENSTORM: $THIS: Attempt $TRIES at constructing river flux boundary condition (fort.20) file has failed. After 2 attempts, the default flux boundary condition file '$DEFAULTFILE' will be used."
            sleep 60
         fi
      done
   fi
   if [[ $SUCCESS = no ]]; then
      error "$ENSTORM: $THIS: Using default river flux boundary condition file '$DEFAULTFILE'."
      ln -s $DEFAULTFILE ./fort.20 2>> ${SYSLOG}
   fi
}
#
#  see if a task has been running longer than a specified time limit
checkTimeLimit()
{
   STARTTIME=$1
   TIMELIMIT=$2
   THIS="asgs_main.sh>checkTimeLimit()"
   #
   # convert time limit to seconds, assuming it is in the format HH:MM:SS
   hours=${TIMELIMIT:0:2}   # requires leading zero! e.g., 05:00:00
   minutes=${TIMELIMIT:3:2}
   seconds=${TIMELIMIT:6:2}
   # bash interprets numbers with leading zeroes as octal ... the 10# prefix
   # tells bash that the numbers are base 10
   limit=$((10#$hours * 3600 + 10#$minutes * 60 + 10#$seconds)) # in seconds
   endTime=`date +%s`
   runTime=$(($endTime - $STARTTIME))
   if [[ $runTime -gt $limit ]]; then
      hoursEnd=$(($limit / 3600))
      remainder=$(($limit % 3600))
      minutesEnd=$(($remainder / 60))
      secondsEnd=$(($remainder % 60))
      format="%02d:%02d:%02d"
      hms=`printf "$format" $hoursEnd $minutesEnd $secondsEnd`
      warn "$ENSTORM: $THIS: The time limit is $TIMELIMIT but the total time used so far is $hms. Therefore, the time limit has been exceeded."
      return 1
   else
      return 0
   fi
}
#
# watches for the existence of certain files that are written by the job as
# it executes and proceeds according to the status that is indicated by
# those files
monitorJobs()
{  QUEUESYS=$1
   ENSTORM_TEMP=$2
   WALLTIME=$3
   THIS="asgs_main.sh>monitorJobs()"
   #

   RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM_TEMP" "$CURRENT_STATE" "Waiting for $ENSTORM_TEMP job to start."
   logMessage "$ENSTORM_TEMP: $THIS: Waiting for $ENSTORM_TEMP job to start."
   until [[ -e ${ENSTORM_TEMP}.run.start ]]; do
      sleep 10
      RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM_TEMP" "$CURRENT_STATE" "Still waiting for $ENSTORM_TEMP job to start..."
   done
   CURRENT_STATE="RUNN"
   RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM_TEMP" "$CURRENT_STATE" "The $ENSTORM_TEMP job has started."
   logMessage "$ENSTORM_TEMP: $THIS: The $ENSTORM_TEMP job has started."
   startTime=`date +%s`  # epoch seconds
   until [[ -e ${ENSTORM_TEMP}.run.finish || -e ${ENSTORM_TEMP}.run.error ]]; do
      sleep 5 
      # execute the FortCheck.py code to get a %complete status
      if [[ -e "fort.61.nc" ]] ; then
        #pc=`${SCRIPTDIR}/fortcheck.sh fort.61.nc 2>> $SYSLOG`
        #echo "${RMQMessaging_Python} ${SCRIPTDIR}/FortCheck.py fort.61.nc"
        pc=`${RMQMessaging_Python} ${SCRIPTDIR}/FortCheck.py fort.61.nc 2>> $SYSLOG`
        RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM_TEMP" "RUNN" "The $ENSTORM_TEMP job is running..." $pc
      fi
      if ! checkTimeLimit $startTime $WALLTIME ; then
         THIS="asgs_main.sh>monitorJobs()"
         echo "$THIS: The ${ENSTORM_TEMP} job exceeded its wall clock time limit of '$WALLTIME'." > ${ENSTORM_TEMP}.run.error
         # if this job was submitted by mpiexec, then terminate it; otherwise,
         # it could run for a long time, delaying the continued execution
         # of the ASGS (the ASGS won't start the next cycle until all forecast
         # ensemble members in the current cycle have completed); this also
         # prevents cpus from being tied up unnecessarily ...
         # if the job was submitted through a queueing system, then the
         # queueing system will terminate it
         if [[ $QUEUESYS = mpiexec ]]; then
            pid=`grep 'mpiexec subshell pid' ${ADVISDIR}/${ENSTORM}/run.properties | sed 's/mpiexec subshell pid.*://' | sed 's/^\s//'`
            #logMessage "Terminating the $ENSTORM_TEMP job with the command 'kill -TERM `ps --ppid $pid -o pid --no-headers'."
            # need to kill the mpiexec process, but don't know its process ID
            # ... but we do have the process ID of its parent subshell
            kill -TERM `ps --ppid $pid -o pid --no-headers` >> ${SYSLOG} 2>&1
            DATETIME=`date +'%Y-%h-%d-T%H:%M:%S'`
            logMessage "$THIS: $ENSTORM_TEMP job in $PWD terminated by ASGS for exceeding expected wall clock time." >> ${ENSTORM_TEMP}.run.error
         else 
            # if we are over the wall clock limit, wait until the operating system has had a chance
            # to write the job log file, or until 5 minutes  have passed
            overLimitTime=`date +%s`
            until [[ ! -e ${ENSTORM_TEMP}.out ]]; do
               logMessage "$ENSTORM_TEMP: $THIS: Waiting for queueing system to write out the job log file ${ENSTORM_TEMP}.out."
               sleep 60
               nowTime=`date +%s`
               if [[ `expr $nowTime - $overLimitTime` -gt 300 ]]; then
                  warn "$ENSTORM_TEMP: $THIS: After 5 minutes, the ${ENSTORM_TEMP}.out file did not appear. Proceeding with error recovery." 
                  break
               fi
            done
         fi
      fi
   done
   if [[ -e ${ENSTORM_TEMP}.run.error ]]; then
     RMQMessage "EXIT" "$CURRENT_EVENT" "$THIS>$ENSTORM_TEMP" "FAIL" "The $ENSTORM_TEMP run failed; results are not available for this ensemble member for this advisory."
     error "$ENSTORM_TEMP: $THIS: The $ENSTORM_TEMP run failed; results are not available for this ensemble member for this advisory."
     cat ${ENSTORM_TEMP}.run.error >> jobFailed
   fi
   if [[ -e ${ENSTORM_TEMP}.run.finish ]]; then
     CURRENT_STATE="CMPL"
     RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM_TEMP" "$CURRENT_STATE" "The $ENSTORM_TEMP job appears to have run to completion successfully." 
     logMessage "$ENSTORM_TEMP: $THIS: The $ENSTORM_TEMP job appears to have run to completion successfully."
   fi
   RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM_TEMP" "$CURRENT_STATE" "Finished monitoring $ENSTORM_TEMP job."
   logMessage "$ENSTORM_TEMP: $THIS: Finished monitoring $ENSTORM_TEMP job."
}
#
# submits a job to the local queueing system
submitJob()
{  QUEUESYS=$1
   NCPU=$2
   ADCIRCDIR=$3
   ADVISDIR=$4
   SCRIPTDIR=$5
   INPUTDIR=$6
   ENSTORM=$7
   NOTIFYUSER="$8"
   ENV=$9
   ACCOUNT=${10}
   PPN=${11}
   NUMWRITERS=${12}
   HOTSTARTCOMP=${13}
   WALLTIME=${14}
   JOBTYPE=${15}
   #
   THIS="asgs_main.sh>submitJob()"
   #
   CLOPTIONS=""     # command line options
   LOCALHOTSTART=""
   CPUREQUEST=$NCPU   
   if [[ $NUMWRITERS != "0" ]]; then
      CLOPTIONS="-W $NUMWRITERS"
      CPUREQUEST=`expr $NCPU + $NUMWRITERS`
   fi
   # record the number of requested CPUs for use in determining capacity to run another job
   echo "cpurequest : $CPUREQUEST" >> ${ADVISDIR}/${ENSTORM}/run.properties
   echo "ncpu : $NCPU" >> ${ADVISDIR}/${ENSTORM}/run.properties  # number of compute CPUs
   echo "numwriters : $NUMWRITERS" >> ${ADVISDIR}/${ENSTORM}/run.properties  # number of dedicated writer CPUs
   if [[ $HOTSTARTCOMP = subdomain ]]; then
      CLOPTIONS="${CLOPTIONS} -S"
      LOCALHOTSTART="--localhotstart"
   fi
   case $QUEUESYS in 
   #
   #  Load Sharing Facility (LSF); used on topsail at UNC
   "LSF")
      bsub -x -n $NCPU -q $QUEUENAME -o log.%J -e err.%J -a mvapich mpirun $ADCIRCDIR/$JOBTYPE $CLOPTION >> ${SYSLOG}
      ;;
   #
   #  LoadLeveler (often used on IBM systems)
   "LoadLeveler")
      perl $SCRIPTDIR/loadleveler.pl --jobtype $JOBTYPE --ncpu $NCPU --adcircdir $ADCIRCDIR --advisdir $ADVISDIR --inputdir $INPUTDIR --enstorm $ENSTORM --notifyuser $NOTIFYUSER --numwriters $NUMWRITERS $LOCALHOTSTART > $ADVISDIR/$ENSTORM/${JOBTYPE}.ll 2>> ${SYSLOG}
      llsubmit $ADVISDIR/$ENSTORM/${JOBTYPE}.ll >> ${SYSLOG} 2>&1
      ;;
   #
   #  Portable Batch System (PBS); widely used
   "PBS")
      QSCRIPTOPTIONS="--jobtype $JOBTYPE --ncpu $NCPU --queuename $QUEUENAME --account $ACCOUNT --adcircdir $ADCIRCDIR --advisdir $ADVISDIR --qscript $SCRIPTDIR/input/machines/$ENV/$QSCRIPT --enstorm $ENSTORM --notifyuser $NOTIFYUSER --walltime $WALLTIME --submitstring $SUBMITSTRING $LOCALHOTSTART --syslog $SYSLOG"
      if [[ $PPN -ne 0 ]]; then
         QSCRIPTOPTIONS="$QSCRIPTOPTIONS --ppn $PPN"
      fi
      if [[ $NUMWRITERS != "0" ]]; then
         QSCRIPTOPTIONS="$QSCRIPTOPTIONS --numwriters $NUMWRITERS"
      fi
      logMessage "$ENSTORM: $THIS: QSCRIPTOPTIONS is $QSCRIPTOPTIONS"
      perl $SCRIPTDIR/$QSCRIPTGEN $QSCRIPTOPTIONS > $ADVISDIR/$ENSTORM/${JOBTYPE}.pbs 2>> ${SYSLOG}
      logMessage "$ENSTORM: $THIS: Submitting $ADVISDIR/$ENSTORM/${JOBTYPE}.pbs"
      # submit job, check to make sure qsub succeeded, and if not, retry
      while [ true ];  do
         qsub $ADVISDIR/$ENSTORM/${JOBTYPE}.pbs >> ${SYSLOG} 2>&1
         if [[ $? = 0 ]]; then
            break # qsub returned a "success" status
         else
            warn "$ENSTORM: $THIS: qsub $ADVISDIR/$ENSTORM/${JOBTYPE}.pbs failed; will retry in 60 seconds."
            sleep 60
         fi
      done
      ;;
   #
   #  SLURM
   "SLURM")
      QSCRIPTOPTIONS="--jobtype $JOBTYPE --ncpu $NCPU --queuename $QUEUENAME --account $ACCOUNT --partition $PARTITION --reservation $RESERVATION --constraint "$CONSTRAINT" --adcircdir $ADCIRCDIR --advisdir $ADVISDIR --qscript $SCRIPTDIR/input/machines/$ENV/$QSCRIPT --enstorm $ENSTORM --notifyuser $NOTIFYUSER --walltime $WALLTIME --submitstring $SUBMITSTRING $LOCALHOTSTART --syslog $SYSLOG"
      if [[ $PPN -ne 0 ]]; then
         QSCRIPTOPTIONS="$QSCRIPTOPTIONS --ppn $PPN"
      fi
      if [[ $NUMWRITERS != "0" ]]; then
         QSCRIPTOPTIONS="$QSCRIPTOPTIONS --numwriters $NUMWRITERS"
      fi
      logMessage "$ENSTORM: $THIS: QSCRIPTOPTIONS is $QSCRIPTOPTIONS"
      perl $SCRIPTDIR/$QSCRIPTGEN $QSCRIPTOPTIONS > $ADVISDIR/$ENSTORM/${JOBTYPE}.slurm 2>> ${SYSLOG}
      RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Submitting $ADVISDIR/$ENSTORM/${JOBTYPE}.slurm"
      logMessage "$ENSTORM: $THIS: Submitting $ADVISDIR/$ENSTORM/${JOBTYPE}.slurm"

      # submit job, check to make sure qsub succeeded, and if not, retry
      while [ true ];  do
         sbatch $ADVISDIR/$ENSTORM/${JOBTYPE}.slurm >> ${SYSLOG} 2>&1
         if [[ $? = 0 ]]; then
            RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "sbatch ${JOBTYPE}.slurm successful."
            break # sbatch returned a "success" status
         else
            RMQMessage "WARN" "$CURRENT_EVENT" "$THIS>$ENSTORM" "WARN" "sbatch ${JOBTYPE}.slurm failed; will retry in 60 seconds."
            warn "$ENSTORM: $THIS: sbatch $ADVISDIR/$ENSTORM/${JOBTYPE}.slurm failed; will retry in 60 seconds."
            sleep 60
         fi
      done
      ;;
#
#  No queueing system, just mpiexec (used on standalone computers)
   "mpiexec")
      DATETIME=`date +'%Y-%h-%d-T%H:%M:%S'`
      echo "[${DATETIME}] Starting ${JOBTYPE}.${ENSTORM} job in $PWD." >> ${ADVISDIR}/${ENSTORM}/${JOBTYPE}.${ENSTORM}.run.start
      logMessage "$ENSTORM: $THIS: Submitting job via $SUBMITSTRING $CPUREQUEST $ADCIRCDIR/$JOBTYPE $CLOPTION >> ${SYSLOG} 2>&1"
      # submit the parallel job in a subshell
      (
         $SUBMITSTRING $CPUREQUEST $ADCIRCDIR/$JOBTYPE $CLOPTIONS >> ${ADVISDIR}/${ENSTORM}/adcirc.log 2>&1
         ERROVALUE=$?
         RUNSUFFIX="finish"
         DATETIME=`date +'%Y-%h-%d-T%H:%M:%S'`
         if [ $ERROVALUE != 0 ] ; then
            RUNSUFFIX="error"
         fi
         echo "[${DATETIME}] Finished ${JOBTYPE}.${ENSTORM} job in $PWD with return value = $ERROVALUE." >> ${ADVISDIR}/${ENSTORM}/${JOBTYPE}.${ENSTORM}.run.${RUNSUFFIX}
      ) &
      # write the process id for mpiexec to the run.properties file so that monitorJobs()
      # can kill the job if it exceeds the expected wall clock time
      echo "mpiexec subshell pid : $!" >> ${ADVISDIR}/${ENSTORM}/run.properties 2>> ${SYSLOG}
      ;;
#
#  Sun Grid Engine (SGE); used on Sun and many Linux clusters
   "SGE")
      QSCRIPTOPTIONS="--jobtype $JOBTYPE --ncpu $NCPU --ncpudivisor $NCPUDIVISOR --queuename $QUEUENAME --account $ACCOUNT --adcircdir $ADCIRCDIR --advisdir $ADVISDIR --qscript $SCRIPTDIR/input/machines/$ENV/$QSCRIPT --enstorm $ENSTORM --notifyuser $NOTIFYUSER --walltime $WALLTIME --submitstring $SUBMITSTRING --syslog $SYSLOG --numwriters $NUMWRITERS $LOCALHOTSTART"
      perl $SCRIPTDIR/$QSCRIPTGEN $QSCRIPTOPTIONS > $ADVISDIR/$ENSTORM/${JOBTYPE}.sge 2>> ${SYSLOG}
      logMessage "$ENSTORM: $THIS: Submitting $ADVISDIR/$ENSTORM/${JOBTYPE}.sge"
      qsub $ADVISDIR/$ENSTORM/${JOBTYPE}.sge >> ${SYSLOG} 2>&1
      # if qsub failed, resubmit the job 5 times before giving up
      if [[ $? = 1 ]]; then
         rangerResubmit $ADVISDIR $ENSTORM ${JOBTYPE}.sge $SYSLOG
         THIS="asgs_main.sh>submitJob()"
      fi
      ;;
   *)
      RMQMessage "EXIT" "$CURRENT_EVENT" "$THIS>$ENSTORM" "FAIL" "Queueing system $QUEUESYS unrecognized."
      fatal "$ENSTORM: $THIS: Queueing system $QUEUESYS unrecognized."
      ;;
   esac
}
#
# since valid jobs are sometimes rejected on ranger, this function will
# attempt to resubmit rejected jobs 5 times before giving up
rangerResubmit()
{
   ADVISDIR=$1
   ENSTORM=$2
   SCRIPTNAME=$3
   SYSLOG=$4
#
   THIS="asgs_main.sh>rangerResubmit():"
   num_retries=0
   success=0
   while [[ $num_retries -le 5 ]]; do
      logMessage "$ENSTORM: $THIS: SGE rejected the job; will resubmit after 60 seconds."
      sleep 60
      qsub $ADVISDIR/$ENSTORM/$SCRIPTNAME >> ${SYSLOG} 2>&1
      num_retries=`expr $num_retries + 1`
      logMessage "$ENSTORM: $THIS: The number of retries is $num_retries."
      if [[ $? = 0 ]]; then
         success=1
         logMessage "$ENSTORM: $THIS: The job was successfully resubmitted."
         break
      fi
   done
   if [[ $success = 0 ]]; then
      date > $ADVISDIR/$ENSTORM/run.error
      msg="$ENSTORM: $THIS: The job '$ADVISDIR/$ENSTORM/$SCRIPTNAME' was not accepted by SGE after it was resubmitted $num_retries times."
      warn $msg
      echo $msg >> $ADVISDIR/$ENSTORM/run.error
   fi
}
#
# checks to see if a job has failed, and if so, copies it off to
# another directory
handleFailedJob()
{
   RUNDIR=$1
   ADVISDIR=$2
   ENSTORM=$3
   NOTIFYSCRIPT=$4
   HOSTNAME=$5
   STORMNAME=$6
   YEAR=$7
   STORMDIR=$8
   ADVISORY=$9
   LASTADVISORYNUM=${10}
   STATEFILE=${11}
   GRIDFILE=${12}
   EMAILNOTIFY=${13}
   JOB_FAILED_LIST="${14}"
   ARCHIVEBASE=${15}
   ARCHIVEDIR=${16}
   THIS="asgs_main.sh>handleFailedJob()"
   # check to see that the job did not conspicuously fail
   if [[ -e $ADVISDIR/${ENSTORM}/jobFailed ]]; then
      RMQMessage "EXIT" "$CURRENT_EVENT" "$THIS>$ENSTORM" "FAIL" "The job has failed." 0
      warn "$ENSTORM: $THIS: The job has failed."
      FAILDATETIME=`date +'%Y-%h-%d-T%H:%M:%S'`
      # send an email to notify the operator that a job has failed
      $NOTIFYSCRIPT $HOSTNAME $STORM $YEAR $STORMDIR $ADVISORY $ENSTORM $GRIDFILE jobfailed $EMAILNOTIFY $SYSLOG "${JOB_FAILED_LIST}" $ARCHIVEBASE $ARCHIVEDIR
      warn "$ENSTORM: $THIS: Moving failed cycle to 'failed.${FAILDATETIME}'."
      mv $ADVISDIR/$ENSTORM $RUNDIR/failed.${FAILDATETIME} 2>> ${SYSLOG}
   fi
   # roll back the latest advisory number if the nowcast failed
   if [[ $ENSTORM = nowcast ]]; then
      sed 's/ADVISORY=.*/ADVISORY='$LASTADVISORYNUM'/' $STATEFILE > ${STATEFILE}.new 2>> ${SYSLOG}
      mv -f ${STATEFILE}.new $STATEFILE >> ${SYSLOG} 2>&1 
   fi
}

variables_init()
{
# Initialize variables accessed from config.sh to reasonable values
   INSTANCENAME=1
   BACKGROUNDMET=on
   TIDEFAC=off
   TROPICALCYCLONE=off
   WAVES=off
   VARFLUX=off
   MINMAX=continuous
   REINITIALIZESWAN=no
   USERIVERFILEONLY=no
   STORMNAME=stormname
   RIVERSITE=ftp.nssl.noaa.gov
   RIVERDIR=/projects/ciflow/adcirc_info
   RIVERUSER=null
   RIVERDATAPROTOCOL=null
   ELEVSTATIONS=null
   VELSTATIONS=null
   METSTATIONS=null
   GRIDFILE=fort.14
   GRIDNAME=fort14
   OUTPUTOPTIONS=
   ARCHIVEBASE=/dev/null
   ARCHIVEDIR=null
   FORECASTCYCLE="00,06,12,18"
   TRIGGER="rss"
   LASTADVISORYNUM=0
   ADVISORY=0
   FORECASTLENGTH=84
   ALTNAMDIR=null
   HOTSTARTCOMP=fulldomain
   HINDCASTWALLTIME="10:00:00"
   ADCPREPWALLTIME="00:30:00"
   NOWCASTWALLTIME="02:00:00"
   FORECASTWALLTIME="05:00:00"
   TIMESTEPSIZE=1.0
   SWANDT=600
   UMASK=002
   GROUP=""
   DRY=1
   DEMO=
   STORM=0
   YEAR=null
   CSDATE=null
   HOTORCOLD=coldstart
   LASTSUBDIR=null
   FTPSITE=null
   FTPFCSTDIR=null
   FTPHCSTDIR=null
   ADCIRCDIR=null
   SCRATCHDIR=null
   MAILINGLIST=null
   ENV=null
   QUEUESYS=null
   QUEUENAME=null
   SERQUEUE=null
   QCHECKCMD=null
   NCPU=null
   JOBTYPE=null
   NUMWRITERS=0
   ACCOUNT=desktop
   SUBMITSTRING=null
   INTERSTRING=null
   RESULTSHOST=null
   RESULTSPATH=null
   RESULTSUSERNAME=null
   RESULTSPROMPT=null
   RESULTSPASSWORD=null
   NOTIFYUSER=null
   RUNDIR=null
   INPUTDIR=null
   PERL5LIB=
   HOTSTARTFORMAT=null
   STORMDIR=stormdir
   SSHKEY=null
   PPN=1
   VELOCITYMULTIPLIER=1.0
   HOTSWAN=off
   ONESHOT=no      # yes if ASGS is launched by cron
   NCPUCAPACITY=2  # total number of CPUs available to run jobs
   si=-1       # storm index for forecast ensemble; -1 indicates non-forecast
   STATEFILE=null
   ENSTORM=hindcast
   CYCLETIMELIMIT="05:00:00"
   IMAGEMAGICKBINPATH=null
   SERQSCRIPT=null
   SERQSCRIPTGEN=null
   VORTEXMODEL=GAHM
   STORMTRACKOPTIONS="--strengthPercent null"
   PSEUDOSTORM=n
   MESHPROPERTIES=null
   CONTROLPROPERTIES=null 
   NAPROPERTIES=null
   EMAILNOTIFY=no # set to yes to have host platform email notifications
   NOTIFY_SCRIPT=null_notify.sh
   ACTIVATE_LIST=null
   NEW_ADVISORY_LIST=null
   POST_INIT_LIST=null
   POST_LIST=null
   JOB_FAILED_LIST=null
   NOTIFYUSER=null
   PARTITION=null   # for SLURM
   RESERVATION=null # for SLURM
   CONSTRIAINT=null # for SLURM
   ASGSADMIN=null
   PERIODICFLUX=null
   SPATIALEXTRAPOLATIONRAMP=yes
   SPATIALEXTRAPOLATIONRAMPDISTANCE=1.0
# RMQMEssaging
   RMQMessaging="on"  # "on"|"off"

}

#####################################################################
#                 E N D  F U N C T I O N S
#####################################################################
#
#####################################################################
#               B E G I N     E X E C U T I O N
#####################################################################
THIS="asgs_main.sh"
CURRENT_EVENT="STRT"
CURRENT_STATE="INIT"
#
#
# Option Summary
#
# -c : set location of configuration file"
# -e (environment): set the computer that the ASGS is running on"
# -h : show help"
#
# Example:
#   bash asgs_main.sh -c /path/to/config -r /path/to/rundir -e topsail
#
# mail alert
ASGSADMIN=
#
# exit statuses
EXIT_NOT_OK=1
EXIT_OK=0
#
# need to determine standard time format to be used for pasting log files
STARTDATETIME=`date +'%Y-%h-%d-T%H:%M:%S'`

# create directories with default permissions of "775" and
# files with the default permssion of "664"
umask 002

# Initialize variables 
variables_init

#
# first - look for SCRIPTDIR
while getopts "c:e:s:h" optname; do    #<- first getopts for SCRIPTDIR
  case $optname in
    c) CONFIG=${OPTARG}
       if [[ ! -e $CONFIG ]]; then
          echo "ERROR: $CONFIG does not exist."
          exit $EXIT_NOT_OK
       fi 
       ;;
    e) ENV=${OPTARG}
       ;;
    s) STATEFILE=${OPTARG}
       ONESHOT=yes
       ;;
    h) echoHelp
       ;;
  esac
done

# set the file and directory permissions, which are platform dependent
umask $UMASK
# read config file just to get the location of $SCRIPTDIR
. ${CONFIG}
# name asgs log file here
SYSLOG=`pwd`/asgs-${STARTDATETIME}.$$.log  # nld 6-6-2013 SYSLOG must be defined before logging.sh is run.
# Bring in logging functions
. ${SCRIPTDIR}/logging.sh
# Bring in platform-specific configuration
. ${SCRIPTDIR}/platforms.sh
# dispatch environment (using the functions in platforms.sh)
env_dispatch ${ENV}
# Re-read the config file, so that the variables can take precedence over
# the values in the platform-specific functions called by env_dispatch
. ${CONFIG}
# RMQMessaging config
if [[ $RMQMessaging == "on" ]] ; then
   . ${SCRIPTDIR}/asgs-msgr.sh
fi

RUNDIR=$SCRATCHDIR/asgs$$
#SYSLOG=`pwd`/asgs-${STARTDATETIME}.$$.log #nld moved to before logging function is called
# if we are starting from cron, look for a state file
if [[ $ONESHOT = yes ]]; then
   # if it is there, read it
   if [[ -e $STATEFILE ]]; then
      RMQMessage "INFO" "$CURRENT_EVENT" "$THIS" "$CURRENT_STATE" "Reading $STATEFILE for previous ASGS state."
      consoleMessage "$THIS: Reading $STATEFILE for previous ASGS state."
      HOTORCOLD=hotstart
      . $STATEFILE # contains RUNDIR, LASTSUBDIR, ADVISORY and SYSLOG values
   else
      # if the state file is not there, just start from cold
      RMQMessage "INFO" "$CURRENT_EVENT" "$THIS" "$CURRENT_STATE" "The statefile '$STATEFILE' was not found. The ASGS will start cold and create a new statefile."
      consoleMessage "$THIS: The statefile '$STATEFILE' was not found. The ASGS will start cold and create a new statefile."
      HOTORCOLD=coldstart
   fi
else
   # if we are not starting from cron, use the default statefile name,
   # and load it if it is there; if it is not there, just go by the 
   # info in the config file
   STATEFILE=${SCRATCHDIR}/${INSTANCENAME}.state
   if [[ -e $STATEFILE ]]; then
      RMQMessage "INFO" "$CURRENT_EVENT" "$THIS" "$CURRENT_STATE" "Reading $STATEFILE for previous ASGS state."
      consoleMessage "$THIS: Reading $STATEFILE for previous ASGS state."
      HOTORCOLD=hotstart
      . $STATEFILE # contains RUNDIR, LASTSUBDIR, ADVISORY and SYSLOG values
   else
      # this is an ongoing execution, and the statefile does not 
      # exist yet, so create it now using info straight from the 
      # ASGS config file
      echo RUNDIR=${RUNDIR} > $STATEFILE 2>> ${SYSLOG}
      echo LASTSUBDIR=${LASTSUBDIR} >> $STATEFILE 2>> ${SYSLOG}
      echo SYSLOG=${SYSLOG} >> $STATEFILE 2>> ${SYSLOG}
      echo ADVISORY=${ADVISORY} >> $STATEFILE 2>> ${SYSLOG}
   fi
fi

RMQMessage "INFO" "$CURRENT_EVENT" "$THIS" "$CURRENT_STATE" "Please see ASGS log file for detailed information regarding system progress."
consoleMessage "$THIS: Please see ASGS log file for detailed information regarding system progress."
consoleMessage "$THIS: ASGS Start Up MSG: [SYSLOG] The log file is ${SYSLOG}"
RMQMessage "INFO" "$CURRENT_EVENT" "$THIS" "$CURRENT_STATE" "ASGS Start Up MSG: [PROCID] $$"
logMessage "$THIS: ASGS Start Up MSG: [PROCID] $$"
RMQMessage "INFO" "$CURRENT_EVENT" "$THIS" "$CURRENT_STATE" "ASGS Start Up MSG: [SYSLOG] ${SYSLOG}"
logMessage "$THIS: ASGS Start Up MSG: [SYSLOG] ${SYSLOG}"
logMessage "$THIS: The ADCIRC Surge/Spill Guidance System is activated."
logMessage "$THIS: Set permissions with the following umask: $UMASK."
RMQMessage "INFO" "$CURRENT_EVENT" "$THIS" "$CURRENT_STATE" "Configured the ASGS for the ${ENV} platform."
logMessage "$THIS: Configured the ASGS for the ${ENV} platform."
RMQMessage "INFO" "$CURRENT_EVENT" "$THIS" "$CURRENT_STATE" "Configured the ASGS according to the file ${CONFIG}."
logMessage "$THIS: Configured the ASGS according to the file ${CONFIG}."
logMessage "$THIS: ASGS state file is ${STATEFILE}."
RMQMessage "INFO" "$CURRENT_EVENT" "$THIS" "$CURRENT_STATE" "ASGS state file is ${STATEFILE}."

# set a trap for a signal to reread the ASGS config file
trap 'echo Received SIGUSR1. Re-reading ASGS configuration file. ; . $CONFIG' USR1
# catch ^C for a final message
trap 'sigint' INT

#
# check existence of all required files and directories
checkDirExistence $ADCIRCDIR "ADCIRC executables directory"
checkDirExistence $INPUTDIR "directory for input files"
checkDirExistence $OUTPUTDIR "directory for post processing scripts"
checkDirExistence $PERL5LIB "directory for the Date::Pcalc perl module"
#
checkFileExistence $ADCIRCDIR "ADCIRC preprocessing executable" adcprep
checkFileExistence $ADCIRCDIR "ADCIRC parallel executable" padcirc
checkFileExistence $ADCIRCDIR "hotstart time extraction executable" hstime
checkFileExistence "$SCRIPTDIR/tides" "tide_factor executable" tide_fac.x
if [[ $TROPICALCYCLONE = on ]]; then
   checkFileExistence $ADCIRCDIR "asymmetric metadata generation executable" aswip
fi
if [[ $BACKGROUNDMET = on ]]; then
   checkFileExistence $SCRIPTDIR "NAM output reprojection executable (from lambert to geographic)" awip_lambert_interp.x
   checkFileExistence $SCRIPTDIR "NAM output reprojection with spatial extrapolation ramp executable (from lambert to geographic)" lambertInterpRamp.x
   checkFileExistence $SCRIPTDIR "GRIB2 manipulation and extraction executable" wgrib2
fi

if [[ $WAVES = on ]]; then
   JOBTYPE=padcswan
   # @jasonfleming debug checkFileExistence $ADCIRCDIR "ADCIRC+SWAN parallel executable" padcswan
   checkFileExistence $ADCIRCDIR/../swan "SWAN fulldomain hotstart file decomposition executable " unhcat.exe
   checkFileExistence $INPUTDIR "SWAN initialization template file " swaninit.template
   checkFileExistence $INPUTDIR "SWAN control template file" $SWANTEMPLATE
else
   JOBTYPE=padcirc
fi
if [[ $VARFLUX = on || $VARFLUX = default ]]; then
   checkFileExistence $INPUTDIR "River elevation initialization file " $RIVERINIT
   checkFileExistence $INPUTDIR "River flux default file " $RIVERFLUX
fi
#
checkFileExistence $INPUTDIR "ADCIRC mesh file" $GRIDFILE
checkFileExistence $INPUTDIR "ADCIRC template fort.15 file" $CONTROLTEMPLATE
if [[ $ELEVSTATIONS != null ]]; then
   checkFileExistence $INPUTDIR "ADCIRC elevation stations file" $ELEVSTATIONS
fi
if [[ $VELSTATIONS && $VELSTATIONS != null ]]; then
   checkFileExistence $INPUTDIR "ADCIRC velocity stations file" $VELSTATIONS
fi
if [[ $METSTATIONS && $METSTATIONS != null ]]; then
   checkFileExistence $INPUTDIR "ADCIRC meteorological stations file" $METSTATIONS
fi
# fort.13 (nodal attributes) file is optional
if [[ ! -z $NAFILE && $NAFILE != null ]]; then
   checkFileExistence $INPUTDIR "ADCIRC nodal attributes (fort.13) file" $NAFILE
fi

if [[ $HOTORCOLD = hotstart ]]; then
   if [[ $HOTSTARTFORMAT = netcdf ]]; then
      if [[ -d $LASTSUBDIR/hindcast ]]; then
         checkFileExistence "" "ADCIRC hotstart (fort.67.nc) file " $LASTSUBDIR/hindcast/fort.67.nc
      fi
      if [[ -d $LASTSUBDIR/nowcast ]]; then
         checkFileExistence "" "ADCIRC hotstart (fort.67.nc) file " $LASTSUBDIR/nowcast/fort.67.nc
      fi
   else
      if [[ -d $LASTSUBDIR/hindcast ]]; then
         checkFileExistence "" "ADCIRC hotstart (fort.67) file " $LASTSUBDIR/hindcast/PE0000/fort.67
      fi
      if [[ -d $LASTSUBDIR/nowcast ]]; then
         checkFileExistence "" "ADCIRC hotstart (fort.67) file " $LASTSUBDIR/nowcast/PE0000/fort.67
      fi
   fi
fi

THIS="asgs_main.sh"
if [[ -e ${INPUTDIR}/${PREPPEDARCHIVE} ]]; then
   RMQMessage "INFO" "$CURRENT_EVENT" "$THIS" "$CURRENT_STATE" "Found archive of preprocessed input files ${INPUTDIR}/${PREPPEDARCHIVE}."
   logMessage "$THIS: Found archive of preprocessed input files ${INPUTDIR}/${PREPPEDARCHIVE}."
else
   RMQMessage "WARN" "$CURRENT_EVENT" "$THIS" "WARN" "Could not find archive of preprocessed input files ${INPUTDIR}/${PREPPEDARCHIVE}. It will be recreated."
   warn "$THIS: Could not find archive of preprocessed input files ${INPUTDIR}/${PREPPEDARCHIVE}. It will be recreated."
fi
if [[ -e ${INPUTDIR}/${HINDCASTARCHIVE} ]]; then
   RMQMessage "INFO" "$CURRENT_EVENT" "$THIS" "$CURRENT_STATE" "Found archive of preprocessed input files ${INPUTDIR}/${HINDCASTARCHIVE}."
   logMessage "$THIS: Found archive of preprocessed input files ${INPUTDIR}/${HINDCASTARCHIVE}."
else
   RMQMessage "WARN" "$CURRENT_EVENT" "$THIS" "WARN" "Could not find archive of preprocessed input files ${INPUTDIR}/${HINDCASTARCHIVE}. It will be recreated."
   warn "$THIS: Could not find archive of preprocessed input files ${INPUTDIR}/${HINDCASTARCHIVE}. It will be recreated."
fi
#
checkFileExistence $OUTPUTDIR "postprocessing initialization script" $INITPOST
checkFileExistence $OUTPUTDIR "postprocessing script" $POSTPROCESS
checkFileExistence $OUTPUTDIR "email notification script" $NOTIFY_SCRIPT
checkFileExistence ${SCRIPTDIR}/archive "data archival script" $ARCHIVE
#
checkDirExistence ${PERL5LIB}/Date "subdirectory for the Pcalc.pm perl module"
checkFileExistence ${PERL5LIB}/Date "perl module for date calculations" Pcalc.pm

THIS="asgs_main.sh"
#
if [[ $PERIODICFLUX != null ]]; then
   logMessage "$THIS: checking for FLUXCALCULATOR script"
   checkFileExistence "" "perl script for calculating periodic flux boundary" $FLUXCALCULATOR
   checkFileExistence ${PERL5LIB} "AdcGrid perl module used by flux calculator" AdcGrid.pm
fi

THIS="asgs_main.sh"
#
# Check for any issues or inconsistencies in configuration parameters. 
if [[ `expr $NCPU + $NUMWRITERS` -gt $NCPUCAPACITY ]]; then
   fatal "$THIS: NCPUCAPACITY must be greater than or equal to NCPU plus NUMWRITERS, however NCPUCAPACITY=$NCPUCAPACITY and NUMWRITERS=$NUMWRITERS and NCPU=$NCPU."
fi
#
# initialize the directory where this instance of the ASGS will run and
# keep all its files
RMQMessage "INFO" "$CURRENT_EVENT" "$THIS" "$CURRENT_STATE" "The directory $RUNDIR will be used for all files associated with this execution of the ASGS." 
logMessage "$THIS: The directory $RUNDIR will be used for all files associated with this execution of the ASGS."
# add the run directory to the list of alternate directories to look for
# NAM data in
ALTNAMDIR="${ALTNAMDIR},$RUNDIR"
# set directory to get perl date calcs module from
export PERL5LIB=${SCRIPTDIR}:${PERL5LIB} #<- augment, don't write over existing
# see if the storm directory already exists in the scratch space
if [ ! -d $RUNDIR ]; then
    # -p says make the entire path tree if intermediate dirs do not exist
    mkdir -p $RUNDIR #
fi
#
# send out an email to notify users that the ASGS is ACTIVATED
${OUTPUTDIR}/${NOTIFY_SCRIPT} $HOSTNAME $STORM $YEAR $RUNDIR advisory enstorm $GRIDFILE activation $EMAILNOTIFY $SYSLOG "${ACTIVATE_LIST}" $ARCHIVEBASE $ARCHIVEDIR >> ${SYSLOG} 2>&1

#
OLDADVISDIR=null
CSDATE=$COLDSTARTDATE
START=$HOTORCOLD
if [[ -d $LASTSUBDIR/hindcast ]]; then
    OLDADVISDIR=$LASTSUBDIR/hindcast
else
    OLDADVISDIR=$LASTSUBDIR/hindcast
fi

#
###############################
#   BODY OF ASGS STARTS HERE
###############################
if [[ $BACKGROUNDMET = on && $TROPICALCYCLONE = on ]]; then
   NWS=29
   # not ready for this yet
   fatal "$THIS: Background meteorology and tropical cyclone forcing are both turned on in ${CONFIG} but simultaneous use of these two forcing types is not yet supported in ASGS."
fi
#
# If we are coldstarting, perform a hindcast ... this is necessary
# to ramp up forcing and allow transient signals to die away before
# performing a nowcast.
ADVISDIR=null   # determined below
HSTIME=null     # determined below
#
#       H I N D C A S T
#

if [[ $START = coldstart ]]; then
   CURRENT_EVENT="HIND"
   CURRENT_STATE="INIT"
   RMQMessage "INFO" "$CURRENT_EVENT" "$THIS" "$CURRENT_STATE" "Starting hindcast." 
   logMessage "$THIS: Starting hindcast."
   HOTSWAN=off
   ENSTORM=hindcast
   # pick up config info that is specific to the hindcast
   . ${CONFIG}
   ADVISDIR=$RUNDIR/initialize
   mkdir -p $ADVISDIR 2>> ${SYSLOG}
   STORMDIR=$ADVISDIR/$ENSTORM
   mkdir -p $STORMDIR 2>> ${SYSLOG}
   HSTIME=0
   # We assume that the hindcast is only used to spin up tides or
   # initialize rivers ... therefore no met forcing.
   NWS=0
   OLDADVISDIR=$ADVISDIR # initialize with dummy value when coldstarting
   RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Coldstarting." 
   logMessage "$ENSTORM: $THIS: Coldstarting."
   RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Coldstart time is $CSDATE." 
   logMessage "$ENSTORM: $THIS: Coldstart time is '$CSDATE'."
   RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "The initial hindcast duration is '$HINDCASTLENGTH' days."
   logMessage "$ENSTORM: $THIS: The initial hindcast duration is '$HINDCASTLENGTH' days."

   # prepare hindcast control (fort.15) file
   # calculate periodic fux data for insertion in fort.15 if necessary
   if [[ $PERIODICFLUX != null ]]; then
      FLUXOPTIONS="--gridfile ${INPUTDIR}/${GRIDFILE} --outfile $PERIODICFLUX --discharge $RIVERDISCHARGE --units $FLUXUNITS"
      logMessage "$ENSTORM: $THIS: Running $FLUXCALCULATOR with options $FLUXOPTIONS."
      perl $FLUXCALCULATOR $FLUXOPTIONS >> ${SYSLOG} 2>&1 
   fi
   CONTROLOPTIONS="--name $ENSTORM --scriptdir $SCRIPTDIR --advisdir $ADVISDIR --cst $CSDATE --endtime $HINDCASTLENGTH --dt $TIMESTEPSIZE --nws $NWS --hsformat $HOTSTARTFORMAT --advisorynum 0 --controltemplate ${INPUTDIR}/${CONTROLTEMPLATE} $OUTPUTOPTIONS"
   CONTROLOPTIONS="$CONTROLOPTIONS --elevstations ${INPUTDIR}/${ELEVSTATIONS} --velstations ${INPUTDIR}/${VELSTATIONS} --metstations ${INPUTDIR}/${METSTATIONS}"
   CONTROLOPTIONS="$CONTROLOPTIONS --gridname $GRIDNAME" # for run.properties
   CONTROLOPTIONS="$CONTROLOPTIONS --periodicflux $PERIODICFLUX"  # for specifying constant periodic flux
   RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Constructing control file."
   logMessage "$ENSTORM: $THIS: Constructing control file with the following options: $CONTROLOPTIONS."
   perl $SCRIPTDIR/control_file_gen.pl $CONTROLOPTIONS >> ${SYSLOG} 2>&1

   # don't have a meterological forcing (fort.22) file in this case
   # preproces
   CURRENT_STATE="WAIT"
   RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Starting $ENSTORM preprocessing."
   logMessage "$ENSTORM: $THIS: Starting $ENSTORM preprocessing."
   echo "hostname : $HOSTNAME" >> $ADVISDIR/$ENSTORM/run.properties
   echo "instance : $INSTANCENAME" >> $ADVISDIR/$ENSTORM/run.properties
   echo "storm : $STORM" >> $ADVISDIR/$ENSTORM/run.properties
   echo "stormnumber : $STORM" >> $ADVISDIR/$ENSTORM/run.properties
   echo "pseudostorm : $PSEUDOSTORM" >> $ADVISDIR/$ENSTORM/run.properties
   #debugMessage "MESHPROPERTIES is $MESHPROPERTIES CONTROLPROPERTIES is $CONTROLPROPERTIES NAPROPERTIES is $NAPROPERTIES"
   for inputProperties in $MESHPROPERTIES $CONTROLPROPERTIES $NAPROPERTIES; do
      if [[ -e ${INPUTDIR}/$inputProperties ]]; then
         cat ${INPUTDIR}/$inputProperties >> $ADVISDIR/$ENSTORM/run.properties
      else 
         logMessage "$ENSTORM: $THIS: The properties file ${INPUTDIR}/$inputProperties was not found and will not be added to the run.properties file."
      fi
   done
   # make sure the archive of subdomain files is up to date 
   checkArchiveFreshness $PREPPEDARCHIVE $HINDCASTARCHIVE $GRIDFILE $CONTROLTEMPLATE $ELEVSTATIONS $VELSTATIONS $METSTATIONS $NAFILE $INPUTDIR
   THIS="asgs_main.sh"
   logMessage "$THIS: prep $ADVISDIR $INPUTDIR $ENSTORM $START $OLDADVISDIR $ENV $NCPU $PREPPEDARCHIVE $GRIDFILE $ACCOUNT '$OUTPUTOPTIONS' $HOTSTARTCOMP $ADCPREPWALLTIME $HOTSTARTFORMAT $MINMAX $HOTSWAN $NAFILE"
   prep $ADVISDIR $INPUTDIR $ENSTORM $START $OLDADVISDIR $ENV $NCPU $PREPPEDARCHIVE $GRIDFILE $ACCOUNT "$OUTPUTOPTIONS" $HOTSTARTCOMP $ADCPREPWALLTIME $HOTSTARTFORMAT $MINMAX $HOTSWAN $NAFILE
   THIS="asgs_main.sh"
   # check to see that adcprep did not conspicuously fail
   handleFailedJob $RUNDIR $ADVISDIR $ENSTORM ${OUTPUTDIR}/${NOTIFY_SCRIPT} $HOSTNAME hindcast $YEAR $STORMDIR $ADVISORY $LASTADVISORYNUM $STATEFILE $GRIDFILE $EMAILNOTIFY "${JOB_FAILED_LIST}" $ARCHIVEBASE $ARCHIVEDIR
   THIS="asgs_main.sh"
   if [[ ! -d $ADVISDIR/$ENSTORM ]]; then
      fatal "$ENSTORM: $THIS: The prep for the hindcast run has failed."
   fi
   # then submit the job
   CURRENT_STATE="PEND"
   RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Submitting ADCIRC $ENSTORM job."
   logMessage "$ENSTORM: $THIS: Submitting ADCIRC $ENSTORM job."
   cd $ADVISDIR/$ENSTORM 2>> ${SYSLOG}
   JOBTYPE=padcirc  # we won't run waves during the spinup hindcast
   logMessage "$ENSTORM: $THIS: submitJob $QUEUESYS $NCPU $ADCIRCDIR $ADVISDIR $SCRIPTDIR $INPUTDIR $ENSTORM $NOTIFYUSER $ENV $ACCOUNT $PPN $NUMWRITERS $HOTSTARTCOMP $HINDCASTWALLTIME $JOBTYPE"
   submitJob $QUEUESYS $NCPU $ADCIRCDIR $ADVISDIR $SCRIPTDIR $INPUTDIR $ENSTORM "$NOTIFYUSER" $ENV $ACCOUNT $PPN $NUMWRITERS $HOTSTARTCOMP $HINDCASTWALLTIME $JOBTYPE
   THIS="asgs_main.sh"
   # check once per minute until all jobs have finished
   monitorJobs $QUEUESYS ${JOBTYPE}.${ENSTORM} $HINDCASTWALLTIME
   THIS="asgs_main.sh"
   # check to see that the nowcast job did not conspicuously fail
   handleFailedJob $RUNDIR $ADVISDIR $ENSTORM ${OUTPUTDIR}/${NOTIFY_SCRIPT} $HOSTNAME hindcast $YEAR $STORMDIR $ADVISORY $LASTADVISORYNUM $STATEFILE $GRIDFILE $EMAILNOTIFY "${JOB_FAILED_LIST}" $ARCHIVEBASE $ARCHIVEDIR
   THIS="asgs_main.sh"
   if [[ ! -d $ADVISDIR/$ENSTORM ]]; then
      RMQMessage "FAIL" "$CURRENT_EVENT" "$THIS>$ENSTORM" "FAIL" "The hindcast run has failed."
      fatal "$ENSTORM: $THIS: The hindcast run has failed."
   fi

   CURRENT_STATE="CMPL"
   RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "The hindcast run has finished."
   allMessage "$ENSTORM: $THIS: $ENSTORM run finished."
   cd $ADVISDIR 2>> ${SYSLOG}
   OLDADVISDIR=$ADVISDIR
   START=hotstart
   #
   echo RUNDIR=${RUNDIR} > $STATEFILE 2>> ${SYSLOG}
   echo LASTSUBDIR=${OLDADVISDIR} >> $STATEFILE 2>> ${SYSLOG}
   echo SYSLOG=${SYSLOG} >> $STATEFILE 2>> ${SYSLOG}
   echo ADVISORY=${ADVISORY} >> $STATEFILE 2>> ${SYSLOG}
else
   # start from   H O T S T A R T   file
   if [[ `basename $LASTSUBDIR` = nowcast || `basename $LASTSUBDIR` = hindcast ]]; then
      logMessage "$THIS: The LASTSUBDIR path is $LASTSUBDIR but ASGS looks in this path to find either a nowcast or hindcast subdirectory. The LASTSUBDIR parameter is being reset to remove either nowcast or hindcast from the end of it." 
      LASTSUBDIR=`dirname $LASTSUBDIR`
   fi 
   if [[ $LASTSUBDIR = null ]]; then
      RMQMessage "FAIL" "$CURRENT_EVENT" "$THIS>$ENSTORM" "FAIL"  "LASTSUBDIR is set to null, but the ASGS is trying to hotstart."
      fatal "LASTSUBDIR is set to null, but the ASGS is trying to hotstart. Is the STATEFILE $STATEFILE up to date and correct? If not, perhaps it should be deleted. Otherwise, the HOTORCOLD parameter in the ASGS config file has been set to $HOTORCOLD and yet the LASTSUBDIR parameter is still set to null."
   fi
   RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Starting from the hindcast or nowcast subdirectory under '$LASTSUBDIR'."
   logMessage "$ENSTORM: $THIS: Starting from the hindcast or nowcast subdirectory under '$LASTSUBDIR'."
   OLDADVISDIR=$LASTSUBDIR
fi

#
# B E G I N   N O W C A S T / F O R E C A S T   L O O P
while [ true ]; do
   # re-read configuration file to pick up any changes, or any config that is specific to nowcasts
   CURRENT_EVENT="RSTR"
   CURRENT_STATE="NONE"
   ENSTORM=nowcast
   si=-1
   . ${CONFIG}
   FROMDIR=null
   LUN=null       # logical unit number; either 67 or 68
   RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Looking for the directory $OLDADVISDIR/nowcast."
   logMessage "$ENSTORM: $THIS: Looking for the directory $OLDADVISDIR/nowcast."
   if [[ -d $OLDADVISDIR/nowcast ]]; then
       FROMDIR=$OLDADVISDIR/nowcast
   else 
      logMessage "$ENSTORM: $THIS: Looking for the directory $OLDADVISDIR/hindcast."
      if [[ -d $OLDADVISDIR/hindcast ]]; then
          FROMDIR=$OLDADVISDIR/hindcast
      fi
   fi
   # turn SWAN hotstarting on or off as appropriate
   HOTSWAN=off
   if [[ $WAVES = on && $REINITIALIZESWAN = no ]]; then
      # look for a swan hotstart file
      for swanhsfile in PE0000/swan.67 swan.67; do
         if [[ -e $FROMDIR/$swanhsfile ]]; then 
            HOTSWAN=on
            logMessage "Found SWAN hotstart file $FROMDIR/${swanhsfile}."
            break
         fi
         for swanhssuffix in tar.gz tar.bz2 gz bz2; do
            if [[ -e $FROMDIR/${swanhsfile}.${swanhssuffix} ]]; then
               HOTSWAN=on
               logMessage "Found SWAN hotstart file $FROMDIR/${swanhsfile}."
               break
            fi
         done
      done
   fi
   CURRENT_EVENT="PRE1"
   CURRENT_STATE="INIT"
   RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Initializing for NowCast."
   checkHotstart $FROMDIR $HOTSTARTFORMAT  67
   THIS="asgs_main.sh"
   logMessage "$ENSTORM $THIS: Checking the time in seconds since cold start in the hotstart file."
   if [[ $HOTSTARTFORMAT = netcdf ]]; then
      logMessage "$ENSTORM: $THIS: The hotstart format is netcdf."
      if [[ ! -e ${FROMDIR}/fort.67.nc ]]; then
         fatal "$ENSTORM: $THIS: The hotstart file ${FROMDIR}/fort.67.nc was not found."
      fi
      HSTIME=`$ADCIRCDIR/hstime -f ${FROMDIR}/fort.67.nc -n` 2>> ${SYSLOG}
   else
      logMessage "$ENSTORM: $THIS: The hotstart format is binary."
      if [[ ! -e ${FROMDIR}/PE0000/fort.67 ]]; then
         fatal "$ENSTORM: $THIS: The hotstart file ${FROMDIR}/PE0000/fort.67.nc was not found."
      fi
      HSTIME=`$ADCIRCDIR/hstime -f ${FROMDIR}/PE0000/fort.67` 2>> ${SYSLOG}
   fi
   RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "$ENSTORM: The time in the hotstart file is '$HSTIME' seconds."
   logMessage "$ENSTORM: $THIS: The time in the hotstart file is '$HSTIME' seconds."
   cd $RUNDIR 2>> ${SYSLOG}
   #
   # N O W C A S T
   RUNNOWCAST=yes 
   NOWCASTDIR=null    # directory with hotstart files to be used in forecast
   CURRENT_STATE="WAIT"
   RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Checking for new meteorological data every 60 seconds ..."
   logMessage "$ENSTORM: $THIS: Checking for new meteorological data every 60 seconds ..."
   # TROPICAL CYCLONE ONLY
   if [[ $TROPICALCYCLONE = on ]]; then
      BASENWS=20
      if [[ $VORTEXMODEL = ASYMMETRIC ]]; then
         BASENWS=19
      fi
      if [[ $VORTEXMODEL = SYMMETRIC ]]; then
         BASENWS=8
      fi
      NWS=$BASENWS
      if [[ $WAVES = on ]]; then
         NWS=`expr $BASENWS + 300`
      fi
      # download wind data from ftp site every 60 seconds to see if
      # there is a new advisory
      downloadCycloneData $STORM $YEAR $RUNDIR $SCRIPTDIR $OLDADVISDIR $TRIGGER $ADVISORY $FTPSITE $RSSSITE $FDIR $HDIR $STATEFILE
      THIS="asgs_main.sh"
      LASTADVISORYNUM=$ADVISORY
      # pull the latest advisory number from the statefile
      ADVISORY=`grep "ADVISORY" $STATEFILE | sed 's/ADVISORY.*=//' | sed 's/^\s//'` 2>> ${SYSLOG}
echo $STATEFILE, $ADVISORY  # BOB

      ADVISDIR=$RUNDIR/${ADVISORY}
      if [ ! -d $ADVISDIR ]; then
          mkdir $ADVISDIR 2>> ${SYSLOG}
      fi
      NOWCASTDIR=$ADVISDIR/$ENSTORM
      if [ ! -d $NOWCASTDIR ]; then
          mkdir $NOWCASTDIR 2>> ${SYSLOG}
      fi
      RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "$START Storm $STORM advisory $ADVISORY in $YEAR"
      allMessage "$ENSTORM: $THIS: $START Storm $STORM advisory $ADVISORY in $YEAR"
      # move raw ATCF files into advisory directory
      mv *.fst *.dat *.xml *.html $ADVISDIR 2>> ${SYSLOG}
      #
      # prepare nowcast met (fort.22) and control (fort.15) files
      cd $NOWCASTDIR 2>> ${SYSLOG}
      echo "storm : $STORM" >> $ADVISDIR/$ENSTORM/run.properties
      echo "stormnumber : $STORM" >> $ADVISDIR/$ENSTORM/run.properties
      echo "pseudostorm : $PSEUDOSTORM" >> $ADVISDIR/$ENSTORM/run.properties
      METOPTIONS="--dir $ADVISDIR --storm $STORM --year $YEAR --name $ENSTORM --nws $NWS --hotstartseconds $HSTIME --coldstartdate $CSDATE $STORMTRACKOPTIONS"
      CONTROLOPTIONS=" --scriptdir $SCRIPTDIR --metfile $NOWCASTDIR/fort.22 --name $ENSTORM --advisdir $ADVISDIR --dt $TIMESTEPSIZE --nws $NWS --advisorynum $ADVISORY --controltemplate ${INPUTDIR}/${CONTROLTEMPLATE} --hst $HSTIME --cst $CSDATE --hsformat $HOTSTARTFORMAT $OUTPUTOPTIONS"
      RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Generating ADCIRC Met File (fort.22) for nowcast."
      logMessage "$ENSTORM: $THIS: Generating ADCIRC Met File (fort.22) for nowcast with the following options: $METOPTIONS."
      ${SCRIPTDIR}/storm_track_gen.pl $METOPTIONS >> ${SYSLOG} 2>&1
      # get the storm's name (e.g. BERTHA) from the run.properties
      STORMNAME=`grep "storm name" run.properties | sed 's/storm name.*://' | sed 's/^\s//'` 2>> ${SYSLOG}    
      RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "StormName is $STORMNAME"
      # create a GAHM or ASYMMETRIC fort.22 file from the existing track file
      if [[ $VORTEXMODEL = GAHM || $VORTEXMODEL = ASYMMETRIC ]]; then
         $ADCIRCDIR/aswip -n $BASENWS >> ${SYSLOG} 2>&1
         if [[ -e NWS_${BASENWS}_fort.22 ]]; then
            mv fort.22 fort.22.orig >> ${SYSLOG} 2>&1
            cp NWS_${BASENWS}_fort.22 fort.22 >> ${SYSLOG} 2>&1
         fi
      fi
   fi
   # BACKGROUND METEOROLOGY
echo "\$BACKGROUNDMET=$BACKGROUNDMET"  # BOB

   if [[ $BACKGROUNDMET != off ]]; then
      NWS=-12
      if [[ $WAVES = on ]]; then
         NWS=-312
      fi
   fi
   case $BACKGROUNDMET in
      on|NAM)
         RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "NWS is $NWS. Downloading background meteorology."
         logMessage "$ENSTORM: $THIS: NWS is $NWS. Downloading background meteorology."
         logMessage "$ENSTORM: $THIS: downloadBackgroundMet $RUNDIR $SCRIPTDIR $BACKSITE $BACKDIR $ENSTORM $CSDATE $HSTIME $FORECASTLENGTH $ALTNAMDIR $FORECASTCYCLE $ARCHIVEBASE $ARCHIVEDIR $STATEFILE"
         CURRENT_STATE="WAIT"
         downloadBackgroundMet $RUNDIR $SCRIPTDIR $BACKSITE $BACKDIR $ENSTORM $CSDATE $HSTIME $FORECASTLENGTH $ALTNAMDIR $FORECASTCYCLE $ARCHIVEBASE $ARCHIVEDIR $STATEFILE
         CURRENT_STATE="INIT"
         THIS="asgs_main.sh"
         LASTADVISORYNUM=$ADVISORY
         ADVISORY=`grep ADVISORY $STATEFILE | sed 's/ADVISORY.*=//' | sed 's/^\s//'` 2>> ${SYSLOG}
         ADVISDIR=$RUNDIR/${ADVISORY}
         NOWCASTDIR=$ADVISDIR/$ENSTORM
         cd $ADVISDIR 2>> ${SYSLOG}
         RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "$START $ENSTORM cycle $ADVISORY."
         allMessage "$ENSTORM: $THIS: $START $ENSTORM cycle $ADVISORY."
         # convert met files to OWI format
         NAMOPTIONS=" --ptFile ${SCRIPTDIR}/input/${PTFILE} --namFormat grib2 --namType $ENSTORM --applyRamp $SPATIALEXTRAPOLATIONRAMP --rampDistance $SPATIALEXTRAPOLATIONRAMPDISTANCE --awipGridNumber 218 --dataDir $NOWCASTDIR --outDir ${NOWCASTDIR}/ --velocityMultiplier $VELOCITYMULTIPLIER --scriptDir ${SCRIPTDIR}"
         RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM"  "$CURRENT_STATE" "Converting NAM data to OWI format."
         logMessage "$ENSTORM: $THIS: Converting NAM data to OWI format with the following options : $NAMOPTIONS"
         echo perl ${SCRIPTDIR}/NAMtoOWIRamp.pl $NAMOPTIONS 
         perl ${SCRIPTDIR}/NAMtoOWIRamp.pl $NAMOPTIONS >> ${SYSLOG} 2>&1
         # create links to the OWI files
         cd $ENSTORM 2>> ${SYSLOG}
         NAM221=`ls NAM*.221`;
         NAM222=`ls NAM*.222`;
         ln -s $NAM221 fort.221 2>> ${SYSLOG}
         ln -s $NAM222 fort.222 2>> ${SYSLOG}
         ;;
   OWI)
         # this is a hack to enable running pre-existing OWI files for hindcast
         #
         # hard code the file location and assume the names of the files have
         # been prepended with the datetime as follows: 2017110100
         #
         # fort.22 is a symbolic link to the actual file with datatime filename
         if [[ -e ${HDIR}/fort.22 ]]; then
            linkTarget=`readlink ${HDIR}/fort.22`
            newAdvisoryNum=${linkTarget:0:10}
            # record the advisory number to the statefile
            cp -f $STATEFILE ${STATEFILE}.old 2>> ${SYSLOG}
            sed 's/ADVISORY=.*/ADVISORY='$newAdvisoryNum'/' $STATEFILE > ${STATEFILE}.new
            cp -f ${STATEFILE}.new $STATEFILE >> ${SYSLOG} 2>&1 
            LASTADVISORYNUM=$ADVISORY
            ADVISORY=$newAdvisoryNum
         else
            fatal "${HDIR}/fort.22 file was not found."           
         fi
         ADVISDIR=$RUNDIR/${ADVISORY}
         NOWCASTDIR=$ADVISDIR/$ENSTORM
         mkdir -p $NOWCASTDIR 2>> ${SYSLOG}
         cd $ADVISDIR 2>> ${SYSLOG}
         RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "$ENSTORM: $THIS: $START $ENSTORM cycle $ADVISORY."
         allMessage "$ENSTORM: $THIS: $START $ENSTORM cycle $ADVISORY."
         # create links to the OWI files, assuming they already have the
         # adcirc 221, 222, etc file name extensions
         cd $ENSTORM 2>> ${SYSLOG}
         owiFiles=`ls ${HDIR}/${ADVISORY}*.22*`
         for file in $owiFiles; do
            ext=${file##*.}
            if [[ $ext = 22 ]]; then
               cp $file fort.${ext} 2>> ${SYSLOG} # copy fort.22
            else
               ln -s $file fort.${ext} 2>> ${SYSLOG} # symbolically link data
            fi
         done
      ;;
     *) # should be unreachable
        RMQMessage "FAIL" "$CURRENT_EVENT" "$THIS>$ENSTORM" FAIL "BACKGROUNDMET ($BACKGROUNDMET) did not match an allowable value."
        fatal "BACKGROUNDMET did not match an allowable value."
      ;;
   esac
   CONTROLOPTIONS=" --advisdir $ADVISDIR --scriptdir $SCRIPTDIR --name $ENSTORM --dt $TIMESTEPSIZE --nws $NWS --controltemplate ${INPUTDIR}/${CONTROLTEMPLATE} --cst $CSDATE --hstime $HSTIME --hsformat $HOTSTARTFORMAT $OUTPUTOPTIONS"
   # send out an email alerting end users that a new cycle has been issued
   cycleStartTime=`date +%s`  # epoch seconds
   ${OUTPUTDIR}/${NOTIFY_SCRIPT} $HOSTNAME $STORM $YEAR $NOWCASTDIR $ADVISORY $ENSTORM $GRIDFILE newcycle $EMAILNOTIFY $SYSLOG "${NEW_ADVISORY_LIST}" $ARCHIVEBASE $ARCHIVEDIR >> ${SYSLOG} 2>&1
   # activate padcswan based on ASGS configuration
   if [[ $WAVES = on ]]; then
      CONTROLOPTIONS="${CONTROLOPTIONS} --swandt $SWANDT --swantemplate ${INPUTDIR}/${SWANTEMPLATE} --hotswan $HOTSWAN"
   fi
   CONTROLOPTIONS="${CONTROLOPTIONS} --elevstations ${INPUTDIR}/${ELEVSTATIONS} --velstations ${INPUTDIR}/${VELSTATIONS} --metstations ${INPUTDIR}/${METSTATIONS}"
   CONTROLOPTIONS="$CONTROLOPTIONS --gridname $GRIDNAME" # for run.properties
   CONTROLOPTIONS="$CONTROLOPTIONS --periodicflux $PERIODICFLUX"  # for specifying constant periodic flux
   # generate fort.15 file
   RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Generating ADCIRC Control File (fort.15) for $ENSTORM."
   logMessage "$ENSTORM: $THIS: Generating ADCIRC Control File (fort.15) for $ENSTORM with the following options: $CONTROLOPTIONS."
   perl $SCRIPTDIR/control_file_gen.pl $CONTROLOPTIONS >> ${SYSLOG} 2>&1
   # if current nowcast ends at same time as last nowcast, don't run it,
   # we'll just use the previous nowcast hotstart file(s) ... to signal that
   # this is the case, control_file_gen.pl won't write the 'runme' file
   if [[ ! -e $NOWCASTDIR/runme ]]; then
      RUNNOWCAST=no
   fi
   echo "hostname : $HOSTNAME" >> $NOWCASTDIR/run.properties
   echo "instance : $INSTANCENAME" >> $NOWCASTDIR/run.properties
   #debugMessage "MESHPROPERTIES is $MESHPROPERTIES CONTROLPROPERTIES is $CONTROLPROPERTIES NAPROPERTIES is $NAPROPERTIES"
   for inputProperties in $MESHPROPERTIES $CONTROLPROPERTIES $NAPROPERTIES; do
      if [[ -e ${INPUTDIR}/$inputProperties ]]; then
         cat ${INPUTDIR}/$inputProperties >> $ADVISDIR/$ENSTORM/run.properties
      else 
         logMessage "$ENSTORM: $THIS: The properties file ${INPUTDIR}/$inputProperties was not found and will not be added to the run.properties file."
      fi
   done

   CURRENT_STATE="PEND"
   if [[ $RUNNOWCAST = yes ]]; then
      RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Starting nowcast for cycle $ADVISORY."
      allMessage "$ENSTORM: $THIS: Starting nowcast for cycle '$ADVISORY'."
      # get river flux nowcast data, if configured to do so
      if [[ $VARFLUX = on ]]; then
         downloadRiverFluxData $ADVISDIR ${INPUTDIR}/${GRIDFILE} $RIVERSITE $RIVERDIR $RIVERUSER $RIVERDATAPROTOCOL $ENSTORM $CSDATE $HSTIME $SCRIPTDIR ${INPUTDIR}/${RIVERFLUX} $USERIVERFILEONLY
         THIS="asgs_main.sh"
      fi
      if [[ $VARFLUX = default ]]; then
         ln -s ${INPUTDIR}/${RIVERFLUX} ./fort.20 2>> ${SYSLOG}
      fi
      # preprocess
      checkArchiveFreshness $PREPPEDARCHIVE $HINDCASTARCHIVE $GRIDFILE $CONTROLTEMPLATE $ELEVSTATIONS $VELSTATIONS $METSTATIONS $NAFILE $INPUTDIR
      THIS="asgs_main.sh"
      RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Nowcast preprocessing."
      logMessage "$ENSTORM: $THIS: Nowcast preprocessing."
      logMessage "$ENSTORM: $THIS: prep $ADVISDIR $INPUTDIR $ENSTORM $START $OLDADVISDIR $ENV $NCPU $PREPPEDARCHIVE $GRIDFILE $ACCOUNT '$OUTPUTOPTIONS' $HOTSTARTCOMP $ADCPREPWALLTIME $HOTSTARTFORMAT $MINMAX $HOTSWAN $NAFILE"
      prep $ADVISDIR $INPUTDIR $ENSTORM $START $FROMDIR $ENV $NCPU $PREPPEDARCHIVE $GRIDFILE $ACCOUNT "$OUTPUTOPTIONS" $HOTSTARTCOMP $ADCPREPWALLTIME $HOTSTARTFORMAT $MINMAX $HOTSWAN $NAFILE
      THIS="asgs_main.sh"
      # check to see that adcprep did not conspicuously fail
      handleFailedJob $RUNDIR $ADVISDIR $ENSTORM ${OUTPUTDIR}/${NOTIFY_SCRIPT} $HOSTNAME $STORMNAME $YEAR $STORMDIR $ADVISORY $LASTADVISORYNUM $STATEFILE $GRIDFILE $EMAILNOTIFY "${JOB_FAILED_LIST}" $ARCHIVEBASE $ARCHIVEDIR
      THIS="asgs_main.sh"
      # if handleFailedJob has detected a problem, it will rename the 
      # nowcast directory; therefore, the non-existence of the nowcast
      # directory is evidence that something has gone wrong in prep
      if [[ ! -d $NOWCASTDIR ]]; then
         continue  # abandon this nowcast and wait for the next one
      fi

      CURRENT_STATE="CMPL"
      RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Nowcast preprocessing complete."

      JOBTYPE=padcirc
      HOTSWAN=on
      if [[ $WAVES = on ]]; then
         JOBTYPE=padcswan
      fi

      # then submit the job
      CURRENT_STATE="CMPL"
      RMQMessage "INFO" "$CURRENT_EVENT" "$JOBTYPE" "$CURRENT_STATE" "Submitting $ENSTORM:$JOBTYPE job."
      logMessage "$ENSTORM: $THIS: Submitting $ENSTORM job."
      cd $ADVISDIR/$ENSTORM 2>> ${SYSLOG}
      logMessage "$ENSTORM: $THIS: submitJob $QUEUESYS $NCPU $ADCIRCDIR $ADVISDIR $SCRIPTDIR $INPUTDIR $ENSTORM $NOTIFYUSER $ENV $ACCOUNT $PPN $NUMWRITERS $HOTSTARTCOMP $NOWCASTWALLTIME $JOBTYPE"

      CURRENT_EVENT="NOWC"
      CURRENT_STATE="PEND"
      submitJob $QUEUESYS $NCPU $ADCIRCDIR $ADVISDIR $SCRIPTDIR $INPUTDIR $ENSTORM "$NOTIFYUSER" $ENV $ACCOUNT $PPN $NUMWRITERS $HOTSTARTCOMP $NOWCASTWALLTIME $JOBTYPE
      THIS="asgs_main.sh"
      # check once per minute until all jobs have finished
      monitorJobs $QUEUESYS ${JOBTYPE}.${ENSTORM} $NOWCASTWALLTIME
      THIS="asgs_main.sh"
      # check to see that the nowcast job did not conspicuously fail
      handleFailedJob $RUNDIR $ADVISDIR $ENSTORM ${OUTPUTDIR}/${NOTIFY_SCRIPT} $HOSTNAME $STORMNAME $YEAR $STORMDIR $ADVISORY $LASTADVISORYNUM $STATEFILE $GRIDFILE $EMAILNOTIFY "${JOB_FAILED_LIST}" $ARCHIVEBASE $ARCHIVEDIR
      THIS="asgs_main.sh"
      if [[ ! -d $NOWCASTDIR ]]; then
         continue # abandon this nowcast and wait for the next one
      fi
      # nowcast finished, get on with it
      CURRENT_STATE="CMPL"
      RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Nowcast run finished."
      allMessage "$ENSTORM: $THIS: Nowcast run finished."
      #
      # archive nowcast
      RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Initiating nowcast archival process, if any."
      logMessage "$ENSTORM: $THIS: Initiating nowcast archival process, if any."
      ${SCRIPTDIR}/archive/${ARCHIVE} $CONFIG $ADVISDIR $STORM $YEAR $ADVISORY $HOSTNAME $ENSTORM $CSDATE $HSTIME $GRIDFILE $OUTPUTDIR $SYSLOG $SSHKEY >> ${SYSLOG} 2>&1
      THIS="asgs_main.sh"
      RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Nowcast complete for advisory $ADVISORY ."
      allMessage "$ENSTORM: $THIS: Nowcast complete for advisory '$ADVISORY.'"
      cd $ADVISDIR 2>> ${SYSLOG}
   else
      # we didn't run the nowcast, because our latest nowcast data end 
      # at the same time as the previous nowcast data, so we can just use
      # the prior cycle's nowcast hotstart file
      logMessage "$ENSTORM: $THIS: The nowcast data end at the same time as the hindcast/nowcast data from the previous cycle. As a result, a nowcast will not be run on this cycle; this cycle's forecast(s) will be hotstarted from the hindcast/nowcast of the previous cycle."
      RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Skipping the submission of the nowcast job and proceeding directly to the forecast(s)."
      logMessage "$ENSTORM: $THIS: Skipping the submission of the nowcast job and proceeding directly to the forecast(s)."
      NOWCASTDIR=$FROMDIR
   fi
   # write the ASGS state file
   LASTSUBDIR=`echo $NOWCASTDIR | sed 's/\/nowcast//g ; s/\/hindcast//g'`
   echo RUNDIR=${RUNDIR} > $STATEFILE 2>> ${SYSLOG}
   echo LASTSUBDIR=${LASTSUBDIR} >> $STATEFILE 2>> ${SYSLOG}
   echo SYSLOG=${SYSLOG} >> $STATEFILE 2>> ${SYSLOG}
   echo ADVISORY=${ADVISORY} >> $STATEFILE 2>> ${SYSLOG}
   #
   # F O R E C A S T
   #
   ENSTORM="forecast"
   CURRENT_EVENT="PRE2"
   CURRENT_STATE="INIT"
   RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Starting forecast for advisory '$ADVISORY'."
   allMessage "$ENSTORM: $THIS: Starting forecast for advisory '$ADVISORY'."
   checkHotstart $NOWCASTDIR $HOTSTARTFORMAT 67
   THIS="asgs_main.sh"
   if [[ $HOTSTARTFORMAT = netcdf ]]; then
      HSTIME=`$ADCIRCDIR/hstime -f ${NOWCASTDIR}/fort.67.nc -n` 2>> ${SYSLOG}
   else
      HSTIME=`$ADCIRCDIR/hstime -f ${NOWCASTDIR}/PE0000/fort.67` 2>> ${SYSLOG}
   fi
   logMessage "$ENSTORM: $THIS: The time in the hotstart file is '$HSTIME' seconds."
   si=0
   while [ $si -lt $ENSEMBLESIZE ]; do    
      # source config file to pick up any configuration changes, or any
      # config that is specific to forecasts, and set up the current 
      # ensemble member
      ENSTORM=forecast  # to pick up forecast-related config from config file
      . ${CONFIG}
      JOBTYPE=padcirc
      HOTSWAN=on
      if [[ $WAVES = on ]]; then
         JOBTYPE=padcswan
      fi
      # Check for a misconfiguration where the Operator has set the  
      # number of CPUs and number of writers greater than the total
      # number of CPUs that will ever be available.
      if [[ `expr $NCPU + $NUMWRITERS` -gt $NCPUCAPACITY ]]; then
         error "$ENSTORM: $THIS: The requested number of CPUs for $ENSTORM is set to $NCPU and the number of writer processors has been set to $NUMWRITERS but the total number of requested CPUs exceeds the NCPUCAPACITY parameter value of ${NCPUCAPACITY}; therefore this forecast ensemble member will never be able to execute. This forecast ensemble member is being abandoned."
         # increment the ensemble member counter
         si=$[$si + 1];
         continue 
      fi
      subDirs=`find ${ADVISDIR} -maxdepth 1 -type d -print`
      #debugMessage "subDirs is $subDirs" # jgfdebug
      if [[ ! -z $subDirs ]]; then  # see if we have any ensemble member directories 
         # continuously loop to see if conditions are right to submit the next job
         while [ true ]; do
            # check to see if the deadline has passed for submitting 
            # forecast jobs for this cycle.
            if ! checkTimeLimit $cycleStartTime $CYCLETIMELIMIT ; then
               THIS="asgs_main.sh"
               warn "[${DATETIME}] $ENSTORM: $THIS: The deadline for submitting jobs ($CYCLETIMELIMIT) has passed for this cycle." 
               break 2
            fi
            # total up the number of cpus currently engaged and compare with capacity
            cpusEngaged=0         
            for ensembleMemDir in $subDirs; do
               # ignore the nowcast and the advisory directory itself
               if [[ $ensembleMemDir = $ADVISDIR || $ensembleMemDir = "./nowcast" || $ensembleMemDir = "." || $ensembleMemDir = "$ADVISDIR/nowcast" ]]; then 
                  #debugMessage "ensembleMemDir $ensembleMemDir is the same as ADVISDIR $ADVISDIR" #jgfdebug
                  continue 
               fi
               # parse the run.properties to see what the cpu request is for this job
               # ... if the was never submitted, there won't be a cpurequest property 
               cpuRequest=`grep 'cpurequest' $ensembleMemDir/run.properties | sed 's/cpurequest.*://' | sed 's/^\s//'`
               if [[ -z $cpuRequest ]]; then
                  continue   # this job was never submitted, so doesn't count; go to the next directory
               fi
               # parse out the name of the ensemble member
               ensembleMemName=`basename $ensembleMemDir`
               runType=`awk '$1 == "Model" { print tolower($3) }' ${ensembleMemDir}/run.properties`
               # look to see if the job is complete
               if [[ ! -e $ensembleMemDir/${runType}.${ensembleMemName}.run.finish ]]; then 
                  # job is still going, add its cpus to the total that are currently engaged
                  cpusEngaged=`expr $cpusEngaged + $cpuRequest`
               fi
            done
            debugMessage "$ENSTORM: $THIS: The next ensemble member ('$ENSTORM') requires $NCPU compute cores and $NUMWRITERS dedicated writer cores. The number of CPUs currently engaged is $cpusEngaged. The max number of cores that can be engaged is $NCPUCAPACITY."
            if [[ `expr $NCPU + $NUMWRITERS + $cpusEngaged` -le $NCPUCAPACITY ]]; then
               #debugMessage "Sufficient capacity exists to run the next job."
               break      # we now have the spare capacity to run this ensemble member
            else 
               RMQMessage "WARN" "$CURRENT_EVENT" "$THIS>$ENSTORM" "WARN"  "Insufficient capacity to submit the next job. Sleeping for 1 minute."
               logMessage "$ENSTORM: $THIS: Insufficient capacity to submit the next job. Sleeping for 1 minute."
               sleep 60   # not enough cores available; sleep for a minute, then recheck/recalculate
            fi
         done
      fi
      # turn SWAN hotstarting on or off as appropriate
      HOTSWAN=off
      if [[ $WAVES = on && $REINITIALIZESWAN = no ]]; then
         # look for a swan hotstart file
         for swanhsfile in PE0000/swan.67 swan.67; do
            if [[ -e $FROMDIR/$swanhsfile ]]; then 
               HOTSWAN=on
               RMQMessage "INFO" "$THIS>$ENSTORM" "$CURRENT_STATE" "Found SWAN hotstart file $FROMDIR/${swanhsfile}."
               logMessage "Found SWAN hotstart file $FROMDIR/${swanhsfile}."
               break
            fi
            for swanhssuffix in tar.gz tar.bz2 gz bz2; do
               if [[ -e $FROMDIR/${swanhsfile}.${swanhssuffix} ]]; then
                  HOTSWAN=on
                  RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Found SWAN hotstart file $FROMDIR/${swanhsfile}."
                  logMessage "Found SWAN hotstart file $FROMDIR/${swanhsfile}."
                  break
               fi
            done
         done
      fi
      STORMDIR=$ADVISDIR/$ENSTORM
      if [ ! -d $STORMDIR ]; then
         mkdir $STORMDIR 2>> ${SYSLOG}
      fi
      cd $STORMDIR 2>> ${SYSLOG}
      RUNFORECAST=yes
      # TROPICAL CYCLONE ONLY
      if [[ $TROPICALCYCLONE = on ]]; then
         BASENWS=20
         if [[ $VORTEXMODEL = ASYMMETRIC ]]; then
            BASENWS=19
         fi
         if [[ $VORTEXMODEL = SYMMETRIC ]]; then
            BASENWS=8
         fi
         NWS=$BASENWS
         if [[ $WAVES = on ]]; then
            NWS=`expr $BASENWS + 300`
         fi
         METOPTIONS=" --dir $ADVISDIR --storm $STORM --year $YEAR --coldstartdate $CSDATE --hotstartseconds $HSTIME --nws $NWS --name $ENSTORM $STORMTRACKOPTIONS"
         if [[ ${PERCENT} != default ]]; then
            echo "modified : y" >> run.properties 2>> ${SYSLOG}
            echo "track_modified : fort.22" >> run.properties 2>> ${SYSLOG}
            if [[ ! $ENSTORM =~ maxWindSpeedOnly ]]; then
               METOPTIONS="$METOPTIONS --percent ${PERCENT}"
            fi
         else
            echo "modified : n" >> run.properties 2>> ${SYSLOG}
         fi
         echo "storm : $STORM" >> $ADVISDIR/$ENSTORM/run.properties
         echo "stormnumber : $STORM" >> $ADVISDIR/$ENSTORM/run.properties
         echo "pseudostorm : $PSEUDOSTORM" >> $ADVISDIR/$ENSTORM/run.properties
         CONTROLOPTIONS="--cst $CSDATE --scriptdir $SCRIPTDIR --advisdir $ADVISDIR --dt $TIMESTEPSIZE --nws $NWS --advisorynum $ADVISORY --controltemplate ${INPUTDIR}/${CONTROLTEMPLATE} --hst $HSTIME --metfile ${STORMDIR}/fort.22 --name $ENSTORM --hsformat $HOTSTARTFORMAT $OUTPUTOPTIONS"
         RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Generating ADCIRC Met File (fort.22) for $ENSTORM."
         logMessage "$ENSTORM: $THIS: Generating ADCIRC Met File (fort.22) for $ENSTORM with the following options: $METOPTIONS."
         ${SCRIPTDIR}/storm_track_gen.pl $METOPTIONS >> ${SYSLOG} 2>&1
         if [[ $BASENWS = 19 || $BASENWS = 20 ]]; then
            # create a new file that contains metadata and has the Rmax
            # in it already ... potentially with Rmax changes if desired
            ASWIPOPTIONS=""
            if [[ ${PERCENT} != default && $ENSTORM =~ maxWindSpeedOnly ]]; then
               ASWIPOPTIONS="-X ${PERCENT}"
               echo "variation maxWindSpeedOnly : ${PERCENT}" >> run.properties 2>> ${SYSLOG}
            fi
            if [[ ${PERCENT} != default && ${RMAX} = scaled ]]; then
               ASWIPOPTIONS="-P ${PERCENT}"
               echo "variation rMax : ${PERCENT}" >> run.properties 2>> ${SYSLOG}
            fi
            if [[ ${RMAX} != default && ${RMAX} != scaled ]]; then
               ASWIPOPTIONS="${ASWIPOPTIONS} -R ${RMAX}"
               echo "variation constant rMax : ${PERCENT}" >> run.properties 2>> ${SYSLOG}
               echo "modified : y" >> run.properties 2>> ${SYSLOG}
            fi
            RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Running aswip fort.22 preprocessor for $ENSTORM."
            logMessage "$ENSTORM: $THIS: Running aswip fort.22 preprocessor for $ENSTORM with the following options: $ASWIPOPTIONS."
            $ADCIRCDIR/aswip -n $BASENWS $ASWIPOPTIONS >> ${SYSLOG} 2>&1
            if [[ -e NWS_${BASENWS}_fort.22 ]]; then
               mv fort.22 fort.22.orig 2>> ${SYSLOG} 
               cp NWS_${BASENWS}_fort.22 fort.22 2>> ${SYSLOG}
            fi
         fi
      fi

      CURRENT_STATE="WAIT"
      # BACKGROUND METEOROLOGY ONLY
      if [[ $BACKGROUNDMET = on ]]; then
         NWS=-12
         if [[ $WAVES = on ]]; then
            NWS=-312
         fi
         allMessage "$ENSTORM: $THIS: $START $ENSTORM cycle $ADVISORY."
         # download and convert met files to OWI format
         RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Downloading background meteorology."
         logMessage "$ENSTORM: $THIS: Downloading background meteorology."
         logMessage "$ENSTORM: $THIS: downloadBackgroundMet $RUNDIR $SCRIPTDIR $BACKSITE $BACKDIR $ENSTORM $CSDATE $HSTIME $FORECASTLENGTH $ALTNAMDIR $FORECASTCYCLE $ARCHIVEBASE $ARCHIVEDIR" $STATEFILE
         CURRENT_STATE="WAIT"
         downloadBackgroundMet $RUNDIR $SCRIPTDIR $BACKSITE $BACKDIR $ENSTORM $CSDATE $HSTIME $FORECASTLENGTH $ALTNAMDIR $FORECASTCYCLE $ARCHIVEBASE $ARCHIVEDIR $STATEFILE
         CURRENT_STATE="INIT"
         THIS="asgs_main.sh"
         cd $ADVISDIR/${ENSTORM} 2>> ${SYSLOG}
         NAMOPTIONS=" --ptFile ${SCRIPTDIR}/input/${PTFILE} --namFormat grib2 --namType $ENSTORM --applyRamp $SPATIALEXTRAPOLATIONRAMP --rampDistance $SPATIALEXTRAPOLATIONRAMPDISTANCE --awipGridNumber 218 --dataDir ${STORMDIR} --outDir ${STORMDIR}/ --velocityMultiplier $VELOCITYMULTIPLIER --scriptDir ${SCRIPTDIR}"
         RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE"  "Converting NAM data to OWI format."
         logMessage "$ENSTORM: $THIS: Converting NAM data to OWI format with the following options : $NAMOPTIONS"
         perl ${SCRIPTDIR}/NAMtoOWIRamp.pl $NAMOPTIONS >> ${SYSLOG} 2>&1
         CONTROLOPTIONS=" --scriptdir $SCRIPTDIR --advisdir $ADVISDIR --name $ENSTORM --dt $TIMESTEPSIZE --nws $NWS --controltemplate ${INPUTDIR}/${CONTROLTEMPLATE} --cst $CSDATE --hstime $HSTIME --hsformat $HOTSTARTFORMAT $OUTPUTOPTIONS"
         # create links to the OWI files
         NAM221=`ls NAM*.221`;
         NAM222=`ls NAM*.222`;
         ln -s $NAM221 fort.221 2>> ${SYSLOG}
         ln -s $NAM222 fort.222 2>> ${SYSLOG}
         if [[ ! -e $STORMDIR/runme ]]; then
            RUNFORECAST=no
         fi
      fi
      if [[ $WAVES = on ]]; then
         CONTROLOPTIONS="${CONTROLOPTIONS} --swandt $SWANDT --swantemplate ${INPUTDIR}/${SWANTEMPLATE} --hotswan $HOTSWAN"
      fi
      CONTROLOPTIONS="${CONTROLOPTIONS} --elevstations ${INPUTDIR}/${ELEVSTATIONS} --velstations ${INPUTDIR}/${VELSTATIONS} --metstations ${INPUTDIR}/${METSTATIONS}"
      CONTROLOPTIONS="$CONTROLOPTIONS --gridname $GRIDNAME" # for run.properties
      CONTROLOPTIONS="$CONTROLOPTIONS --periodicflux $PERIODICFLUX"  # for specifying constant periodic flux
      RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Generating ADCIRC Control File (fort.15) for $ENSTORM."
      logMessage "$ENSTORM: $THIS: Generating ADCIRC Control File (fort.15) for $ENSTORM with the following options: $CONTROLOPTIONS."
      perl $SCRIPTDIR/control_file_gen.pl $CONTROLOPTIONS >> ${SYSLOG} 2>&1
      if [[ ! -d $STORMDIR ]]; then continue; fi
      # get river flux nowcast data, if configured to do so
      if [[ $VARFLUX = on ]]; then
         downloadRiverFluxData $ADVISDIR ${INPUTDIR}/${GRIDFILE} $RIVERSITE $RIVERDIR $RIVERUSER $RIVERDATAPROTOCOL $ENSTORM $CSDATE $HSTIME $SCRIPTDIR ${INPUTDIR}/${RIVERFLUX} $USERIVERFILEONLY
         THIS="asgs_main.sh"
      fi
      if [[ $VARFLUX = default ]]; then
         ln -s ${INPUTDIR}/${RIVERFLUX} ./fort.20 2>> ${SYSLOG}
      fi
      echo "hostname : $HOSTNAME" >> ${STORMDIR}/run.properties
      echo "instance : $INSTANCENAME" >> ${STORMDIR}/run.properties
      # write the start and end dates of the forecast to the run.properties file
      if [[ -e $RUNDIR/forecast.properties ]]; then
         cat $RUNDIR/forecast.properties >> ${STORMDIR}/run.properties
      fi
      #debugMessage "MESHPROPERTIES is $MESHPROPERTIES CONTROLPROPERTIES is $CONTROLPROPERTIES NAPROPERTIES is $NAPROPERTIES"
      for inputProperties in $MESHPROPERTIES $CONTROLPROPERTIES $NAPROPERTIES; do
         if [[ -e ${INPUTDIR}/$inputProperties ]]; then
            cat ${INPUTDIR}/$inputProperties >> $ADVISDIR/$ENSTORM/run.properties
         else
            logMessage "$ENSTORM: $THIS: The properties file ${INPUTDIR}/$inputProperties was not found and will not be added to the run.properties file."
         fi
      done
      # recording the ensemble member number may come in handy for load
      # balancing the postprocessing, particularly for CERA
      echo "forecastEnsembleMemberNumber : $si" >> ${STORMDIR}/run.properties
      CURRENT_EVENT="FORE"
      CURRENT_STATE="PEND"
      if [[ $RUNFORECAST = yes ]]; then
         # set up post processing for the forecast, including initiation
         # of real time post processing
         ${OUTPUTDIR}/${INITPOST} $CONFIG $ADVISDIR $STORM $YEAR $ADVISORY $HOSTNAME $ENSTORM $CSDATE $HSTIME $GRIDFILE $OUTPUTDIR $SYSLOG $SSHKEY >> ${SYSLOG} 2>&1
         # preprocess
         checkArchiveFreshness $PREPPEDARCHIVE $HINDCASTARCHIVE $GRIDFILE $CONTROLTEMPLATE $ELEVSTATIONS $VELSTATIONS $METSTATIONS $NAFILE $INPUTDIR
         THIS="asgs_main.sh"
         logMessage "$ENSTORM: $THIS: Starting $ENSTORM preprocessing with the following command: prep $ADVISDIR $INPUTDIR $ENSTORM $START $NOWCASTDIR $ENV $NCPU $PREPPEDARCHIVE $GRIDFILE $ACCOUNT "$OUTPUTOPTIONS" $HOTSTARTCOMP $ADCPREPWALLTIME $HOTSTARTFORMAT $MINMAX $HOTSWAN $NAFILE"
         prep $ADVISDIR $INPUTDIR $ENSTORM $START $NOWCASTDIR $ENV $NCPU $PREPPEDARCHIVE $GRIDFILE $ACCOUNT "$OUTPUTOPTIONS" $HOTSTARTCOMP $ADCPREPWALLTIME $HOTSTARTFORMAT $MINMAX $HOTSWAN $NAFILE
         THIS="asgs_main.sh"
         handleFailedJob $RUNDIR $ADVISDIR $ENSTORM ${OUTPUTDIR}/${NOTIFY_SCRIPT} $HOSTNAME $STORMNAME $YEAR $STORMDIR $ADVISORY $LASTADVISORYNUM $STATEFILE $GRIDFILE $EMAILNOTIFY "${JOB_FAILED_LIST}" $ARCHIVEBASE $ARCHIVEDIR
         THIS="asgs_main.sh"
         # if the prep task was successful, the ensemble member directory will still be there
         if [[ -d $STORMDIR ]]; then
            JOBTYPE=padcirc
            if [[ $WAVES = on ]]; then
               JOBTYPE=padcswan
            fi
            # then submit the job
            RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "$CURRENT_STATE" "Submitting ensemble member $ENSTORM for forecast."
            allMessage "$ENSTORM: $THIS: Submitting ensemble member $ENSTORM for forecast."
            CURRENT_EVENT="FORE"
            CURRENT_STATE="PEND"
            submitJob $QUEUESYS $NCPU $ADCIRCDIR $ADVISDIR $SCRIPTDIR $INPUTDIR $ENSTORM "$NOTIFYUSER" $ENV $ACCOUNT $PPN $NUMWRITERS $HOTSTARTCOMP $FORECASTWALLTIME $JOBTYPE
            THIS="asgs_main.sh"
            # monitor for completion and post process in a subshell running in the background
            # ... this allows us to go on to the next ensemble member
            (            
               monitorJobs $QUEUESYS ${JOBTYPE}.${ENSTORM} $FORECASTWALLTIME
               THIS="asgs_main.sh"
               handleFailedJob $RUNDIR $ADVISDIR $ENSTORM ${OUTPUTDIR}/${NOTIFY_SCRIPT} $HOSTNAME $STORMNAME $YEAR $STORMDIR $ADVISORY $LASTADVISORYNUM $STATEFILE $GRIDFILE $EMAILNOTIFY "${JOB_FAILED_LIST}" $ARCHIVEBASE $ARCHIVEDIR
               THIS="asgs_main.sh"
               # only attempt post processing if this ensemble member ended successfully
               if [[ -d $STORMDIR ]]; then
                  RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "CMPL"  "The $ENSTORM job ended successfully. Starting postprocessing."
                  logMessage "$ENSTORM: $THIS: The $ENSTORM job ended successfully. Starting postprocessing."
                  ${OUTPUTDIR}/${POSTPROCESS} $CONFIG $ADVISDIR $STORM $YEAR $ADVISORY $HOSTNAME $ENSTORM $CSDATE $HSTIME $GRIDFILE $OUTPUTDIR $SYSLOG $SSHKEY >> ${SYSLOG} 2>&1
                  # notify analysts that new results are available
                  ${OUTPUTDIR}/${NOTIFY_SCRIPT} $HOSTNAME $STORM $YEAR $STORMDIR $ADVISORY $ENSTORM $GRIDFILE results $EMAILNOTIFY $SYSLOG "${POST_LIST}" $ARCHIVEBASE $ARCHIVEDIR >> ${SYSLOG} 2>&1  
               fi
            ) &
         fi
      fi
      si=`expr $si + 1`
   done
   # allow all ensemble members and associated post processing to complete
   RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "RUNN" "All forecast ensemble members have been submitted."
   logMessage "$ENSTORM: $THIS: All forecast ensemble members have been submitted."
   logMessage "$ENSTORM: $THIS: Waiting for completion of the remaining forecast ensemble members (and their associated post processing)."
   wait   # @jasonfleming: I suppose I put this here so that the archive script would have a complete set of results, but now (20170823) I am thinking that the archive script needs to be resilient to having not all the results available so that it doesn't hold up the whole show
   # 
   # ARCHIVE FORECAST
   logMessage "$ENSTORM: $THIS: Initiating archival process, if any."
   ${SCRIPTDIR}/archive/${ARCHIVE} $CONFIG $ADVISDIR $STORM $YEAR $ADVISORY $HOSTNAME    $ENSTORM $CSDATE $HSTIME $GRIDFILE $OUTPUTDIR $SYSLOG $SSHKEY >> ${SYSLOG} 2>&1
   THIS="asgs_main.sh"
   allMessage "$ENSTORM: $THIS: Forecast complete for advisory '$ADVISORY.'"
   LASTSUBDIR=null # don't need this any longer
   # if we ran the nowcast on this cycle, then this cycle's nowcast becomes 
   # the basis for the next cycle; on the other hand, if we used a previous 
   # nowcast as the basis for this cycle, then that previous nowcast will 
   # also have to be the basis for the next cycle 
   if [[ $RUNNOWCAST = yes ]]; then
      OLDADVISDIR=$ADVISDIR
   fi
   if [[ $ONESHOT = yes ]]; then
      wait      # allow any background processes to complete
      exit $OK  # exit because the ASGS will be started once again by cron
   fi

   CURRENT_EVENT="REND"
   RMQMessage "INFO" "$CURRENT_EVENT" "$THIS>$ENSTORM" "NONE" "Cycle Complete"
done
