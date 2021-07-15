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
# Copyright(C) 2021 Jason Fleming
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
# The defaults for parameters that can be reset in this config file
# are preset in the following scripts:
# {SCRIPTDIR/platforms.sh               # also contains Operator-specific info
# {SCRIPTDIR/config/config_defaults.sh
# {SCRIPTDIR/config/mesh_defaults.sh
# {SCRIPTDIR/config/forcing_defaults.sh
# {SCRIPTDIR/config/io_defaults.sh
# {SCRIPTDIR/config/operator_defaults.sh
#-------------------------------------------------------------------

# Fundamental

INSTANCENAME=HSOFS_nam_jgf  # "name" of this ASGS process

# Input files and templates

GRIDNAME=HSOFS
source $SCRIPTDIR/config/mesh_defaults.sh

# Physical forcing (defaults set in config/forcing_defaults)

TIDEFAC=on            # tide factor recalc
HINDCASTLENGTH=30.0   # length of initial hindcast, from cold (days)
BACKGROUNDMET=on      # NAM download/forcing
FORECASTCYCLE="06"
   forecastSelection="strict"
TROPICALCYCLONE=off   # tropical cyclone forcing
STORM=05             # storm number, e.g. 05=ernesto in 2006
YEAR=2021            # year of the storm
WAVES=on             # wave forcing
#STATICOFFSET=0.1524
REINITIALIZESWAN=no   # used to bounce the wave solution
VARFLUX=off           # variable river flux forcing
CYCLETIMELIMIT="99:00:00"

# Computational Resources (related defaults set in platforms.sh)

NCPU=959                     # number of compute CPUs for all simulations
NUMWRITERS=1
NCPUCAPACITY=9999

# Post processing and publication

INTENDEDAUDIENCE=general    # can also be "developers-only" or "professional"
POSTPROCESS=( "includeWind10m.sh" "createOPeNDAPFileList.sh" "opendap_post.sh" )
OPENDAPNOTIFY="jason.g.fleming@gmail.com"

# Initial state (overridden by STATEFILE after ASGS gets going)

COLDSTARTDATE=auto
HOTORCOLD=hotstart      # "hotstart" or "coldstart"
LASTSUBDIR=https://fortytwo.cct.lsu.edu/thredds/fileServer/2021/nam/2021063006/HSOFS/supermic.hpc.lsu.edu/HSOFS_nam_jgf/namforecast

# Scenario packages TO RUN

HINDCASTSCENARIOS=( "hindcast" )
NOWCASTSCENARIOS=( "nowcastWind10m" "nowcast" )
FORECASTSCENARIOS=( "namforecastWind10m" "namforecast" )

# Scenario DEFINITIONS (would need to be in a separate file that we "source" into asgs_main.sh)
# alternatively, each of these would write a block of json for asgs_main.sh to read and act upon
case $SCENARIO in
    # SPINUP scenario definitions
    "hindcast")
        FINISH_SPINUP_SCENARIO=( "output/createOPeNDAPFileList.sh" "output/opendap_post.sh" )   # post spinup to opendap
        OPENDAPNOTIFY="jason.g.fleming@gmail.com,janelle.fleming@seahorsecoastal.com"
        ;;

    # NOWCAST scenario definitions
    "nowcastWind10m")
        FINISH_NOWCAST_SCENARIO=( ) # empty the hook script array -- nothing needed for this nowcast scenario
        # need to update $SCRIPTDIR/config/io_defaults.sh for Wind10m layer to nuke out the FINISH_NOWCAST_SCENARIO hook
        source $SCRIPTDIR/config/io_defaults.sh # sets met-only mode based on "Wind10m" suffix
        ;;
    "nowcast")
        FINISH_NOWCAST_SCENARIO=( "output/createOPeNDAPFileList.sh" "output/opendap_post.sh" )  # post nowcast to opendap
        OPENDAPNOTIFY="jason.g.fleming@gmail.com,janelle.fleming@seahorsecoastal.com"
        ;;

    # FORECAST scenario definitions
    "namforecastWind10m")
        source $SCRIPTDIR/config/io_defaults.sh # sets met-only mode based on "Wind10m" suffix
        ;;
    "namforecast")
        # use default settings specified above this case block
        ;;
    "nhcConsensusWind10m")
        source $SCRIPTDIR/config/io_defaults.sh # sets met-only mode based on "Wind10m" suffix
        ;;
    "nhcConsensus")
        # use default settings specified above this case block
        ;;
    "veerRight100Wind10m")
        source $SCRIPTDIR/config/io_defaults.sh # sets met-only mode based on "Wind10m" suffix
        PERCENT=100
        ;;
    "veerRight100")
        PERCENT=100
        ;;
    "veerLeft100Wind10m")
        source $SCRIPTDIR/config/io_defaults.sh # sets met-only mode based on "Wind10m" suffix
        PERCENT=-100
        ;;
    "veerLeft100")
        PERCENT=-100
        ;;
    *)
        echo "CONFIGRATION ERROR: Unknown scenario: '$SCENARIO'."
        ;;
esac
# end scenario DEFINITIONS

PREPPEDARCHIVE=prepped_${GRIDNAME}_${INSTANCENAME}_${NCPU}.tar.gz
HINDCASTARCHIVE=prepped_${GRIDNAME}_hc_${INSTANCENAME}_${NCPU}.tar.gz