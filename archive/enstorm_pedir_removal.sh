#!/bin/bash
#----------------------------------------------------------------
# esnstorm_pedir_removal.sh: Removes the PE* subdirectories that were
# created by adcprep for use in a parallel adcirc simulation.
#----------------------------------------------------------------
# Copyright(C) 2017--2021 Jason Fleming
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
# This script gets all the information it needs from the
# run.properties file instead of using command line arguments.
#----------------------------------------------------------------
THIS=archive/enstorm_pedir_removal.sh
# this assumes this script is executed in the dirctory that is to be archived
SCENARIODIR=$PWD
SCRIPTDIR=`sed -n 's/[ ^]*$//;s/path.scriptdir\s*:\s*//p' run.properties`
#echo "scriptdir is $SCRIPTDIR" # jgfdebug
#echo "PWD is $PWD" # jgfdebug
. ${SCRIPTDIR}/monitoring/logging.sh
. ${SCRIPTDIR}/platforms.sh           # contains hpc platform configurations
. ${SCRIPTDIR}/properties.sh          # contains loadProperties subroutine
# load properties
declare -A properties
loadProperties $SCENARIODIR/run.properties
CYCLE=${properties['advisory']}
SCENARIO=${properties['scenario']}
SCENARIOLOG=${properties["monitoring.logging.file.scenariolog"]}
CYCLELOG=${properties["monitoring.logging.file.cyclelog"]}
SYSLOG=${properties["monitoring.logging.file.syslog"]}
LOGFILE=${SCENARIODIR}/enstorm_pedir_removal.sh.log
# run configuration
WAVES=${properties["coupling.waves"]}
SWANHSCOMPRESSION=${properties["coupling.waves.swan.swanhscompression"]}
hotstartcomp=${properties['adcirc.hotstartcomp']}
#echo "hotstartcomp is $hotstartcomp" # jgfdebug
#
scenarioMessage "$THIS: Starting cleanup of subdomain (PE*) subdirectories." $LOGFILE
#
if [[ $WAVES = on ]]; then
   scenarioMessage "$THIS: Wave coupling with SWAN is active." $LOGFILE
   SWANDIR=${properties["path.swandir"]}
   scenarioMessage "$THIS: The path to SWAN executables is ${SWANDIR}." $LOGFILE
   #
   # set name of SWAN executable that knits together the subdomain
   # SWAN hotstart files into a fulldomain SWAN hotstart file
   hSWANExe=null
   if [[ -e ${SWANDIR}/HottifySWAN.x ]]; then
      hSWANExe=HottifySWAN.x
   fi
   if [[ -e ${SWANDIR}/unhcat.exe ]]; then
      hSWANExe=unhcat.exe
   fi
   if [[ $hSWANExe = null ]]; then
      warn "cycle $CYCLE: $SCENARIO: $THIS: Could not find HottifySWAN.x or unhcat.exe in the directory '${SWANDIR}'." $LOGFILE
      exit
   else
      scenarioMessage "$THIS: The SWAN hotstart composition executable is ${SWANDIR}/${hSWANExe}." $LOGFILE
   fi
   #
   # preserve the swan log file and swan Errfile (if any) so we can see it later
   # FIXME: the name of the asgs_swan.prt file is provided in swaninit but it
   # is hardcoded here as asgs_swan.prt
   for file in ./PE0000/asgs_swan.prt ./PE0000/Errfile ; do
      if [[ -e $file ]]; then
         scenarioMessage "$THIS: Preserving SWAN $file file." $LOGFILE
         cp $file . > errmsg 2>&1 || warn "cycle $CYCLE: $SCENARIO: $THIS: Could not copy '$file' to $PWD: `cat errmsg`." $LOGFILE
      fi
   done
   for file in swan.67 swan.68 ; do
      if [[ -e $file ]]; then
         scenarioMessage "Renaming existing fulldomain $file file to ${file}.start." $LOGFILE
         mv $file ${file}.start > errmsg 2>&1 || warn "cycle $CYCLE: $SCENARIO: $THIS: Could not rename '$file' to ${file}.start: `cat errmsg`." $LOGFILE
      fi
      # tar up the swan subdomain hotstart files to create a fast
      # start for hotstarted jobs using the same number of processors;
      # then construct fulldomain swan hotstart file(s) and compress
      if [[ -e ./PE0000/$file ]]; then
         (
            scenarioMessage "$THIS: Creating tar archive of subdomain $file files."
            tar cf ${file}.tar ./PE*/$file 1> tar.log 2> errmsg && cat tar.log | tee -a $LOGFILE >> $SCENARIOLOG || warn "cycle $CYCLE: $SCENARIO: $THIS: Could not create a tar archive of subdomain $file files: `cat errmsg`." $LOGFILE
            if [[ $SWANHSCOMPRESSION = yes ]]; then
               bzip2 ${file}.tar > errmsg 2>&1 || warn "cycle $CYCLE: $SCENARIO: $THIS: Could not bzip2 '${file}.tar': `cat errmsg`." $LOGFILE
            fi
            scenarioMessage "$THIS: Finished creating tar archive of subdomain $file files." $LOGFILE
         ) &
         (
            scenarioMessage "$THIS: Creating fulldomain SWAN hotstart file from subdomain $file files." $LOGFILE
            ${SWANDIR}/$hSWANExe <<EndInput | tee $LOGFILE >> $SCENARIOLOG 2>&1
1
$file
F
EndInput
            if [[ $SWANHSCOMPRESSION = yes ]]; then
               bzip2 $file > errmsg 2>&1 || warn "cycle $CYCLE: $SCENARIO: $THIS: Could not bzip2 '$file': `cat errmsg`." $LOGFILE
            fi
            scenarioMessage "$THIS: Finished creating fulldomain SWAN hotstart file from subdomain $file files." $LOGFILE
         ) &
      fi
   done
fi
#
# allow all backgrounded processes to finish before going on to
# delete subdomain directories
wait
#
# archive the subdomain fort.16 log files
tar cjf fort.16.tar.bz2 ./PE*/fort.16 1> tar.log 2> errmsg && cat tar.log | tee -a $LOGFILE >> $SCENARIOLOG || warn "cycle $CYCLE: $SCENARIO: $THIS: Could not create a tar archive of subdomain fort.16 files: `cat errmsg`." $LOGFILE
#
# archive grib2 files if any
if ls *grib* >&/dev/null ; then
   scenarioMessage "$THIS: Archiving grib files." $LOGFILE
   tar czf grib.tar.gz *grib* 1> tar.log 2> errmsg && cat tar.log | tee -a $LOGFILE >> $SCENARIOLOG || warn "cycle $CYCLE: $SCENARIO: $THIS: Could not create a tar archive of grib2 files: `cat errmsg`." $LOGFILE
   rm -rf *grib* 2>> $SYSLOG
else
   scenarioMessage "$THIS: There are no grib files to archive." $LOGFILE
fi
#
#
# pull in platform-specific value for the command used to remove directories
# (some platforms have a special command that is nicer for their filesystem)
REMOVALCMD="rm -rf"
HPCENVSHORT=${properties["hpc.hpcenvshort"]}
env_dispatch ${HPCENVSHORT}
THIS=archive/enstorm_pedir_removal.sh
# now delete the subdomain directories
rm errmsg ; touch errmsg
# FIXME : this needs to be cleaned up so that the subdomain hotstart
# files are archived in a .tar.gz file or even post processed into
# a fulldomain hotstart file instead of just turning
# off the deletion of the PE* subdirectories
if [[ $hotstartcomp != "subdomain" ]]; then
   for dir in `ls -d PE*`; do
      $REMOVALCMD $dir 2>> errmsg | tee -a $LOGFILE >> $SCENARIOLOG
   done
fi
if [[ -s errmsg  ]]; then
   warn "cycle $CYCLE: $SCENARIO: $THIS: Could not remove PE subdirectories: `cat errmsg`." $LOGFILE
fi
for file in metis_graph.txt partmesh.txt fort.80 ; do
   if [[ -e $file ]]; then
      $REMOVALCMD partmesh.txt
   fi
done
scenarioMessage "$THIS: Finished cleanup of subdomain (PE*) subdirectories." $LOGFILE
