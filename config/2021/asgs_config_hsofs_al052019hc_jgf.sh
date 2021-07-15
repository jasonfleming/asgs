#!/bin/sh
#-------------------------------------------------------------------
# config.sh: This file is read at the beginning of the execution of the ASGS to
# set up the runs  that follow. It is reread at the beginning of every cycle,
# every time it polls the datasource for a new advisory. This gives the user
# the opportunity to edit this file mid-storm to change config parameters
# (e.g., the name of the queue to submit to, the addresses on the mailing list,
# etc)
#-------------------------------------------------------------------
#
# Copyright(C) 2019 Jason Fleming
#
# This file is part of the ADCIRC Surge Guidance System (ASGS).
#
# The ASGS is free software: you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# ASGS is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# the ASGS.  If not, see <http://www.gnu.org/licenses/>.
#-------------------------------------------------------------------

# Fundamental

INSTANCENAME=hsofs_al052019hc_jgf     # "name" of this ASGS process

# Input files and templates

GRIDNAME=hsofs
source $SCRIPTDIR/config/mesh_defaults.sh

# Physical forcing (defaults set in config/forcing_defaults.sh)

TIDEFAC=on               # tide factor recalc
   HINDCASTLENGTH=30.0   # length of initial hindcast, from cold (days)
BACKGROUNDMET=off        # NAM download/forcing
   FORECASTCYCLE="06"
TROPICALCYCLONE=on       # tropical cyclone forcing
   STORM=05              # storm number, e.g. 05=ernesto in 2006
   YEAR=2019             # year of the storm
WAVES=on                 # wave forcing
   REINITIALIZESWAN=no   # used to bounce the wave solution
VARFLUX=off               # variable river flux forcing
#
STATICOFFSET=0.30        # (m), assumes a unit offset file is available
#
CYCLETIMELIMIT="99:00:00"

# Computational Resources (related defaults set in platforms.sh)

NCPU=1799                     # number of compute CPUs for all simulations
NCPUCAPACITY=9999
NUMWRITERS=1
if [[ $HPCENVSHORT = "hatteras" ]]; then
   NCPU=639 # max on hatteras
fi
if [[ $HPCENVSHORT = "queenbee" ]]; then
   NCPU=959
fi

# Post processing and publication

INTENDEDAUDIENCE=general    # "general" | "developers-only" | "professional"
#POSTPROCESS=( accumulateMinMax.sh createMaxCSV.sh cpra_slide_deck_post.sh includeWind10m.sh createOPeNDAPFileList.sh opendap_post.sh )
NOWCASTPOST=( accumulateMinMax.sh createMaxCSV.sh includeWind10m.sh createOPeNDAPFileList.sh opendap_post.sh )
POSTPROCESS=( accumulateMinMax.sh createMaxCSV.sh includeWind10m.sh createOPeNDAPFileList.sh opendap_post.sh )
OPENDAPNOTIFY="asgs.cera.lsu@gmail.com,jason.g.fleming@gmail.com,taylorgasher@gmail.com"
NOTIFY_SCRIPT=ncfs_cyclone_notify.sh
RMQMessaging_Enable="off"      # "on"|"off"  
RMQMessaging_Transmit="off"    #  enables message transmission ("on" | "off")

# Initial state (overridden by STATEFILE after ASGS gets going)

COLDSTARTDATE=auto
HOTORCOLD=hotstart
#LASTSUBDIR=http://fortytwo.cct.lsu.edu:8080/thredds/fileServer/2019/nam/2019082506/hsofs/queenbee.loni.org/namhsofs/namforecast
#LASTSUBDIR=http://fortytwo.cct.lsu.edu:8080/thredds/fileServer/2019/al05/30/hsofs/queenbee.loni.org/hsofs_al052019_jgf_0.3/nhcConsensus
LASTSUBDIR=http://fortytwo.cct.lsu.edu:8080/thredds/fileServer/2019/al05/30/hsofs/queenbee.loni.org/hsofs_al052019_jgf_0.3/nhcConsensus


#LASTSUBDIR=/work/jgflemin/asgs45215/30
#
NOWCASTPACKAGESIZE=2
# $ni is the scenario index for the nowcast, set and incremented in asgs_main.sh
if [[ $si -eq -1 ]]; then
   case $ni in 
       0)
          ENSTORM=nowcastWind10m
          SCENARIO=$ENSTORM
          FROMSCENARIO=nowcast
          source $SCRIPTDIR/config/io_defaults.sh # sets met-only mode based on "Wind10m" suffix
          NOWCASTPOST=( null_post.sh )
          ;;
       1)
          ENSTORM=nowcast
          SCENARIO=$ENSTORM
          FROMSCENARIO=nowcast
          ;;
       *)   
          echo "CONFIGRATION ERROR: Unknown ensemble member number: '$si'."
          ;;
    esac
fi
# Scenario package

#PERCENT=default
SCENARIOPACKAGESIZE=0
# $si is the scenario index for the forecast, set and incremented in asgs_main.sh
case $si in
   -2) 
       ENSTORM=hindcast
       ;;
   -1)      
       # do nothing ... this is a nowcast
       ;;
    0)
       ENSTORM=nhcConsensusWind10m
       source $SCRIPTDIR/config/io_defaults.sh # sets met-only mode based on "Wind10m" suffix
       ;;
    1)
       ENSTORM=nhcConsensus
       ;;

    2)
       ENSTORM=veerLeft50Wind10m
       PERCENT=-50
       source $SCRIPTDIR/config/io_defaults.sh # sets met-only mode based on "Wind10m" suffix
       ;;
    3)
       ENSTORM=veerLeft50
       PERCENT=-50
       ;;

    4)
       ENSTORM=veerLeft100Wind10m
       PERCENT=-100
       source $SCRIPTDIR/config/io_defaults.sh # sets met-only mode based on "Wind10m" suffix
       ;;
    5)
       ENSTORM=veerLeft100
       PERCENT=-100
       ;;
    *)   
       echo "CONFIGRATION ERROR: Unknown ensemble member number: '$si'."
      ;;
esac

PREPPEDARCHIVE=prepped_${GRIDNAME}_${INSTANCENAME}_${NCPU}.tar.gz
HINDCASTARCHIVE=prepped_${GRIDNAME}_hc_${INSTANCENAME}_${NCPU}.tar.gz
