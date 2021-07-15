#!/bin/bash
#-----------------------------------------------------------------------
# createOPeNDAPFileList.sh : Construct a list of the files that
# should be posted to OPeNDAP and write the list to run.properties.
#-----------------------------------------------------------------------
# Copyright(C) 2018--2019 Jason Fleming
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
#-----------------------------------------------------------------------
#
THIS=output/createOPeNDAPFileList.sh
# Count command line arguments; use them if provided or use
# run.properties if not.
declare -A properties
SCENARIODIR=$PWD
RUNPROPERTIES=$SCENARIODIR/run.properties
if [[ $# -eq 1 ]]; then
   RUNPROPERTIES=$1
fi
# this script can be called with just one command line option: the
# full path to the run.properties file
echo "Loading properties."
# get loadProperties function
SCRIPTDIR=`sed -n 's/[ ^]*$//;s/path.scriptdir\s*:\s*//p' $RUNPROPERTIES`
source $SCRIPTDIR/properties.sh
# load run.properties file into associative array
loadProperties $RUNPROPERTIES
echo "Finished loading properties."
# now set variables that would otherwise be set by command line arguments
CONFIG=${properties['config.file']}
CYCLEDIR=${properties['path.advisdir']}
CYCLE=${properties['advisory']}
HPCENV=${properties['hpc.hpcenv']}
SCENARIO=${properties['scenario']}
CSDATE=${properties['adcirc.time.coldstartdate']}
HSTIME=${properties['InitialHotStartTime']}
GRIDFILE=${properties['adcirc.file.input.gridfile']}
OUTPUTDIR=${properties['path.outputdir']}
SYSLOG=${properties['monitoring.logging.file.syslog']}
SSHKEY=${properties['post.file.sshkey']}
HPCENVSHORT=${properties['hpc.hpcenvshort']}
HPCENV=${properties['hpc.hpcenv']}
WAVES=${properties['coupling.waves']}
TROPICALCYCLONE=${properties['forcing.tropicalcyclone']}
WAVES=${properties['coupling.waves']}
if [[ $TROPICALCYCLONE != "off" ]]; then
   STORM=${properties['forcing.tropicalcyclone.stormnumber']}
   YEAR=${properties['forcing.tropicalcyclone.year']}
else
   STORM="null"
   YEAR=${CYCLE:0:4}
fi
#
SCENARIODIR=${CYCLEDIR}/${SCENARIO}       # shorthand
CYCLELOG=${properties['monitoring.logging.file.cyclelog']}
SCENARIOLOG=${properties['monitoring.logging.file.scenariolog']}
source ${SCRIPTDIR}/monitoring/logging.sh
source ${SCRIPTDIR}/platforms.sh
# dispatch environment (using the functions in platforms.sh)
env_dispatch ${HPCENVSHORT}
THIS=output/createOPeNDAPFileList.sh
allMessage "$SCENARIO: $THIS: Starting post processing."
# debug scenarioMessage "$THIS: SCENARIO=$SCENARIO ; SCENARIODIR=$SCENARIODIR"
cd ${SCENARIODIR} 2>&1 > errmsg || warn "cycle $CYCLE: $SCENARIO: $THIS: Could not change directory to $SCENARIODIR: `cat $errmsg`"
#---------------------------------------------------------------------------------------------
#---------------------------------------------------------------------------------------------
scenarioMessage "$SCENARIO: $THIS: Creating list of files to post to opendap."
fcstFile=../al${STORM}${YEAR}.fst
bestFile=../bal${STORM}${YEAR}.dat
for file in $fcstFile $bestFile ; do
   if [[ -e $file ]]; then
      cp $file . 2>&1 > errmsg || warn "cycle $CYCLE: $SCENARIO: $THIS: Could not link to $file: `cat $errmsg`"
   fi
done
ceraNonPriorityFiles=( `ls $CONFIG $SYSLOG $CYCLELOG $SCENARIOLOG cpra.post.log *.csv endrisinginun.63.nc everdried.63.nc fort.64.nc fort.68.nc fort.71.nc fort.72.nc fort.73.nc initiallydry.63.nc inundationtime.63.nc maxinundepth.63.nc maxrs.63.nc maxvel.63.nc minpr.63.nc rads.64.nc swan_DIR.63.nc swan_DIR_max.63.nc swan_TMM10.63.nc swan_TMM10_max.63.nc 2>> $SCENARIOLOG` )
ceraPriorityFiles=(`ls run.properties maxele.63.nc fort.63.nc fort.61.nc fort.15 fort.22 *.jpg 2>> $SCENARIOLOG`)
if [[ $TROPICALCYCLONE = on ]]; then
   ceraPriorityFiles=( ${ceraPriorityFiles[*]} `ls al${STORM}${YEAR}.fst bal${STORM}${YEAR}.dat 2>> $SCENARIOLOG` )
fi
#if [[ $WAVES = on ]]; then
   ceraPriorityFiles=( ${ceraPriorityFiles[*]} `ls swan_HS_max.63.nc swan_TPS_max.63.nc swan_HS.63.nc swan_TPS.63.nc 2>> $SCENARIOLOG` )
#fi
dirWind10m=$CYCLEDIR/${SCENARIO}Wind10m
if [[ -d $dirWind10m ]]; then
   ceraPriorityFiles=( ${ceraPriorityFiles[*]} `ls wind10m.maxwvel.63.nc wind10m.fort.74.nc 2>> $SCENARIOLOG` )
   ceraNonPriorityFiles=( ${ceraNonPriorityFiles[*]} `ls maxwvel.63.nc fort.74.nc 2>> $SCENARIOLOG` )
else
   ceraPriorityFiles=( ${ceraPriorityFiles[*]} `ls maxwvel.63.nc fort.74.nc 2>> $SCENARIOLOG` )
fi
FILES=( ${ceraPriorityFiles[*]} "sendNotification" ${ceraNonPriorityFiles[*]} )
#
FILESSTRING="("
for string in ${FILES[*]}; do
   FILESSTRING="$FILESSTRING $string"
done
FILESSTRING="$FILESSTRING )"
echo "post.opendap.files : $FILESSTRING" >> run.properties

