#!/bin/bash
#----------------------------------------------------------------
# forcing_defaults.sh : Functions required for initializing
# parameters that are only related to the forcing.
#----------------------------------------------------------------
# Copyright(C) 2019 Jason Fleming
#
# This file is part of the ADCIRC Surge Guidance System (ASGS).
#
# The ASGS is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ASGS is distributed in the hope that it will be useful,
# # but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with the ASGS.  If not, see <http://www.gnu.org/licenses/>.
#----------------------------------------------------------------
THIS=config/forcing_defaults.sh
allMessage "$THIS: Setting default parameters for forcing."
#
# time between picking up advisory and giving up  on additional scenarios
CYCLETIMELIMIT="05:00:00"
#
#  Meteorological Forcing : Tropical Cyclones
#
#RSSSITE=filesystem
#FTPSITE=filesystem
#FDIR=~/asgs/branches/2014stable/input/sample_advisories/2018
#HDIR=${FDIR}
STORM=07                         # storm number, e.g. 05=ernesto in 2006
YEAR=2018                        # year of the storm
TRIGGER="rssembedded"            # either "ftp" or "rss"
RSSSITE="www.nhc.noaa.gov"       # site information for retrieving advisories
FTPSITE="ftp.nhc.noaa.gov"       # hindcast/nowcast ATCF formatted files
FDIR="/atcf/afst"                # forecast dir on nhc ftp site
HDIR="/atcf/btk"                 # hindcast dir on nhc ftp site
RMAX="default"
PERCENT="default"
VORTEXMODEL="GAHM"
PSEUDOSTORM="no"
#
#  Meteorological Forcing : North American Mesoscale (NAM) Model
#
FORECASTCYCLE="06"
BACKSITE="ftp.ncep.noaa.gov"          # NAM forecast data from NCEP
BACKDIR="/pub/data/nccf/com/nam/prod" # contains the nam.yyyymmdd files
FORECASTLENGTH=84                     # hours of NAM forecast to run (max 84)
PTFILE="ptFile_oneEighth.txt"         # the lat/lons for the OWI background met
ALTNAMDIR="/projects/ncfs/data/asgs5463","/projects/ncfs/data/asgs14174"
VELOCITYMULTIPLIER=1.0
forecastSelection="latest"            # "latest" or "strict"
forecastDownload="only-to-run"        # "only-to-run" or "all"
#
# External data sources : River Flux
#
RIVERSITE="ftp.nssl.noaa.gov"
RIVERDIR="/projects/ciflow/adcirc_info"
RIVERUSER="ldm"
RIVERDATAPROTOCOL="scp"
#
# Model coupling : SWAN
#
REINITIALIZESWAN="no"
SWANHSCOMPRESSION="no"
