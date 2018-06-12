#!/bin/bash
#--------------------------------------------------------------------------
# createPPT.sh 
#--------------------------------------------------------------------------
# Workhorse script to call Matlab and generate hydrograph images,
# build final PPT slide deck, and email slide deck as attachment.
#--------------------------------------------------------------------------
# 
# Copyright(C) 2018 Matthew V Bilskie
# Copyright(C) 2018 Jason Fleming
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
#
#--------------------------------------------------------------------------
#
#
#--------------------------------------------------------------------------
#       GATHER COMMAND LINE ARGUMENTS
#--------------------------------------------------------------------------
POSITIONAL=()
while [[ $# -gt 0 ]]
do
    key="$1"

    case $key in
        -i)
            toolDir="$2"
            shift # past argument
            shift # past value
            ;;
        -s)
            stormDir="$2"
            shift # past argument
            shift # past value
            ;;
        -fig)
            fname="$2"
            shift
            shift
            ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters
#--------------------------------------------------------------------------
#
#
#--------------------------------------------------------------------------
#       SET MATLABPATH TO POINT TO MATLAB SCRIPTS
#--------------------------------------------------------------------------
export MATLABPATH=${toolDir}
#--------------------------------------------------------------------------
#
#
#--------------------------------------------------------------------------
#       PARSE run.properties FILE
#--------------------------------------------------------------------------
coldStartTime=$(grep ColdStartTime run.properties)
coldStartTime=${coldStartTime/ColdStartTime : }
temp1=${coldStartTime:0:8}
temp2=${coldStartTime:8:9}
coldStartTimeUTC="${temp1} ${temp2} UTC"
coldStartTimeCDT=$(TZ="America/Chicago" date -d "${coldStartTimeUTC}" "+%Y-%m-%d %H:%M:%S")

# Parse run.properties to get storm name
storm=$(grep "storm name" run.properties)
storm=${storm/storm name : }

# Parse run.properties to get advisory
advisory=$(grep "advisory :" run.properties)
advisory=${advisory/advisory : }

# Parse run.properties to get forecast advisory start time
forecastValidStart=$(grep forecastValidStart run.properties)
forecastValidStart=${forecastValidStart/forecastValidStart : }
temp1=${forecastValidStart:0:8}
temp2=${forecastValidStart:8:4}
forecastValidStartUTC="${temp1} ${temp2} UTC"
forecastValidStartCDT=$(TZ="America/Chicago" date -d "${forecastValidStartUTC}" "+%Y%m%d%H%M%S")

# Parse run.properties file
${toolDir}/GetInfo4Hydrographs.sh
#--------------------------------------------------------------------------
#
#
#--------------------------------------------------------------------------
#       RUN MATLAB SCRIPT TO GENERATE HYDROGRAPH IMAGES
#--------------------------------------------------------------------------
matlab -nodisplay -nosplash -nodesktop -r "run plot_usace_adcirc.m, exit"
#--------------------------------------------------------------------------
#
#
#--------------------------------------------------------------------------
#       WAIT UNTIL FIGUREGEN IMAGE(S) ARE FINISHED
#--------------------------------------------------------------------------
# Wait until submit-postproc is finished
until [ -f ${stormDir}/postproc.done ]
do
    sleep 5
done
#--------------------------------------------------------------------------
#       RUN PYTHON SCRIPT TO GENERATE PPT SLIDE DECK
#--------------------------------------------------------------------------
cp ${toolDir}/LSU_template.pptx ${stormDir}/
python ${toolDir}/buildPPT.py ${fname}
rm LSU_template.pptx
#--------------------------------------------------------------------------
#
#
#--------------------------------------------------------------------------
#       E-MAIL PPT AS ATTACHMENT
#--------------------------------------------------------------------------
#emailList='mbilsk3@lsu.edu matt.bilskie@gmail.com jason.fleming@seahorsecoastal.com ckaiser@cct.lsu.edu'
emailList='mbilsk3@lsu.edu'
subjectLine="$storm Advisory $advisory PPT"
message="This is an automated message from the ADCIRC Surge Guidance System (ASGS).
New results are attached for STORM $storm ADVISORY $advisory issued on $forecastValidStart CDT"
attachFile=$(cat pptFile.temp)
echo "$message" | mail -s "$subjectLine" -a "$attachFile" $emailList
#--------------------------------------------------------------------------
#
#
#--------------------------------------------------------------------------
#       CLEAN UP
#--------------------------------------------------------------------------
rm cpraHydro.info
rm pptFile.temp
#--------------------------------------------------------------------------