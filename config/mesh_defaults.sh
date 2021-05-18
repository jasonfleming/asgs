#!/bin/bash
#----------------------------------------------------------------
# mesh_defaults.sh : Functions required for initializing
# parameters that are mesh dependent.
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
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with the ASGS.  If not, see <http://www.gnu.org/licenses/>.
#----------------------------------------------------------------
THIS=config/mesh_defaults.sh
allMessage "$THIS: Setting default values for the mesh ${MESH}."
MESHURL=https://asgs-static-assets.sfo2.digitaloceanspaces.com/meshes
NODALATTRIBUTESURL=https://asgs-static-assets.sfo2.digitaloceanspaces.com/nodal-attributes
OFFSETURL=https://asgs-static-assets.sfo2.digitaloceanspaces.com/offsets
UNITOFFSETFILE=null
# The following is common to all meshes and is only used
# for SWAN (WAVES=on); may not give good numerical results
# with ADCIRC+SWAN v52; not clear whether it is correctly
# formatted with ADCIRC+SWAN v55 yet.
SWANTEMPLATE=adcirc_swan_v53_fort.26.template # found in input/meshes/common/swan
#
case $GRIDNAME in
      #
   "LA_v19k-WithUpperAtch_chk")
      #
      INPUTDIR=$SCRIPTDIR/input/meshes/LA_v19k
      GRIDFILE=LA_v19k-WithUpperAtch_chk.grd   # mesh (fort.14) file
      MESHPROPERTIES=${GRIDFILE}.properties
      CONTROLTEMPLATE=LA_v19k-WithUpperAtch.15.template
      # wind at 10m fort.15 template
      CONTROLTEMPLATENOROUGH=LA_v19k-WithUpperAtch.nowindreduction.15.template
      CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
      ELEVSTATIONS=combined_stations_20190327.txt
      VELSTATIONS=combined_stations_20190327.txt
      METSTATIONS=combined_stations_20190327.txt
      NAFILE=LA_v19k-WithUpperAtch_chk.13
      NAPROPERTIES=${NAFILE}.properties
      RIVERINIT=null                           # this mesh has no rivers ...
      RIVERFLUX=null
      HINDCASTRIVERFLUX=null
      # interaction between mesh and models:
      TIMESTEPSIZE=1.0           # adcirc time step size (seconds)
      SWANDT=1200                # swan timestep / coupling interval (seconds)
      # intersection between mesh, models, hpc platform, and number of compute cores:
      HINDCASTWALLTIME="18:00:00" # hindcast wall clock time
      ADCPREPWALLTIME="02:00:00"  # adcprep wall clock time, including partmesh
      NOWCASTWALLTIME="07:00:00"  # longest nowcast wall clock time
      FORECASTWALLTIME="07:00:00" # forecast wall clock time
      # unit offset url https://asgs-static-assets.sfo2.digitaloceanspaces.com/offsets/unit_offset_LA_v19k-WithUpperAtch_chk.dat.xz
      UNITOFFSETFILE=unit_offset_LA_v19k-WithUpperAtch_chk.dat
      ;;
      #
   "LA_v20a-WithUpperAtch_chk"|"LAv20a")
      #
      INPUTDIR=$SCRIPTDIR/input/meshes/LA_v20a
      GRIDFILE=LA_v20a-WithUpperAtch_chk.grd   # mesh (fort.14) file
      MESHPROPERTIES=${GRIDFILE}.properties
      CONTROLTEMPLATE=LA_v20a-WithUpperAtch.15.template
      # wind at 10m fort.15 template
      CONTROLTEMPLATENOROUGH=LA_v20a-WithUpperAtch.nowindreduction.15.template
      CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
      ELEVSTATIONS=combined_stations_20200929.txt
      VELSTATIONS=$ELEVSTATIONS
      METSTATIONS=$ELEVSTATIONS
      NAFILE=LA_v20a-WithUpperAtch_chk.13
      NAPROPERTIES=${NAFILE}.properties
      RIVERINIT=null                           # this mesh has no rivers ...
      RIVERFLUX=null
      HINDCASTRIVERFLUX=null
      # interaction between mesh and models:
      TIMESTEPSIZE=1.0           # adcirc time step size (seconds)
      SWANDT=1200                # swan timestep / coupling interval (seconds)
      # intersection between mesh, models, hpc platform, and number of compute cores:
      HINDCASTWALLTIME="18:00:00" # hindcast wall clock time
      ADCPREPWALLTIME="02:00:00"  # adcprep wall clock time, including partmesh
      NOWCASTWALLTIME="07:00:00"  # longest nowcast wall clock time
      FORECASTWALLTIME="07:00:00" # forecast wall clock time
      # FIXME: no unit offset url
      ;;
      #
   "ec95d"|"EC95d")
      #
      INPUTDIR=$SCRIPTDIR/input/meshes/ec95d
      GRIDFILE=ec_95d.grd   # mesh (fort.14) file
      MESHPROPERTIES=${GRIDFILE}.properties
      CONTROLTEMPLATE=ec_95_fort.15_template   # fort.15 template
      # wind at 10m fort.15 template
      CONTROLTEMPLATENOROUGH=ec_95_nowindreduction.fort.15_template
      CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
      ELEVSTATIONS=cera_stations.txt
      VELSTATIONS=cera_stations.txt
      METSTATIONS=cera_stations.txt
      NAFILE=null
      NAPROPERTIES=${NAFILE}.properties
      RIVERINIT=null                            # this mesh has no rivers ...
      RIVERFLUX=null
      HINDCASTRIVERFLUX=null
      # interaction between mesh and models:
      TIMESTEPSIZE=30.0           # adcirc time step size (seconds)
      SWANDT=1200                # swan timestep / coupling interval (seconds)
      # intersection between mesh, models, hpc platform, and number of compute cores:
      HINDCASTWALLTIME="06:00:00" # hindcast wall clock time
      ADCPREPWALLTIME="01:00:00"  # adcprep wall clock time, including partmesh
      NOWCASTWALLTIME="01:00:00"  # longest nowcast wall clock time
      FORECASTWALLTIME="01:00:00" # forecast wall clock time
      # FIXME: no unit offset url
      ;;
      #
   "tx2008_r35h"|"TX2008")
      #
      INPUTDIR=$SCRIPTDIR/input/meshes/texas2008_r35h
      GRIDFILE=tx2008_r35h.grd # mesh (fort.14) file
      MESHPROPERTIES=${GRIDFILE}.properties
      CONTROLTEMPLATE=tx2008r35h_template.15   # fort.15 template
      # wind at 10m fort.15 template
      CONTROLTEMPLATENOROUGH=tx2008r35h_norough_template.15
      CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
      ELEVSTATIONS=tx2008r35h_stations_20170618.txt
      VELSTATIONS=tx2008r35h_stations_20170618.txt
      METSTATIONS=tx2008r35h_stations_20170618.txt
      NAFILE=tx2008_r35h.13
      NAPROPERTIES=${NAFILE}.properties
      RIVERINIT=null                           # this mesh has no rivers ...
      RIVERFLUX=null
      HINDCASTRIVERFLUX=null
      # interaction between mesh and models:
      TIMESTEPSIZE=1.0           # adcirc time step size (seconds)
      SWANDT=1200                # swan timestep / coupling interval (seconds)
      # intersection between mesh, models, hpc platform, and number of compute cores:
      HINDCASTWALLTIME="18:00:00" # hindcast wall clock time
      ADCPREPWALLTIME="02:00:00"  # adcprep wall clock time, including partmesh
      NOWCASTWALLTIME="07:00:00"  # longest nowcast wall clock time
      FORECASTWALLTIME="07:00:00" # forecast wall clock time
      # unit offset url https://asgs-static-assets.sfo2.digitaloceanspaces.com/offsets/unit_offset_tx2008_r35h.grd.dat.xz
      UNITOFFSETFILE=unit_offset_tx2008_r35h.grd.dat
      ;;
      #
   "tx2017"|"CTXCS2017")
      #
      INPUTDIR=$SCRIPTDIR/input/meshes/tx2017
      GRIDFILE=ctx_gr_p01E01.grd # mesh (fort.14) file
      MESHPROPERTIES=${GRIDFILE}.properties
      CONTROLTEMPLATE=tx2017_template.15   # fort.15 template
      # wind at 10m fort.15 template
      CONTROLTEMPLATENOROUGH=tx2017_norough_template.15
      CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
      ELEVSTATIONS=tx2008r35h_stations_20170618.txt
      VELSTATIONS=tx2008r35h_stations_20170618.txt
      METSTATIONS=tx2008r35h_stations_20170618.txt
      NAFILE=ctx_gr_p01E02_na_p02_fort.13
      NAPROPERTIES=${NAFILE}.properties
      RIVERINIT=null                           # this mesh has no rivers ...
      RIVERFLUX=null
      HINDCASTRIVERFLUX=null
      # interaction between mesh and models:
      TIMESTEPSIZE=0.5           # adcirc time step size (seconds)
      SWANDT=1200 # swan timestep / coupling interval (seconds)
      # intersection between mesh, models, hpc platform, and number of compute cores:
      HINDCASTWALLTIME="24:00:00" # hindcast wall clock time
      ADCPREPWALLTIME="10:00:00"  # adcprep wall clock time, including partmesh
      NOWCASTWALLTIME="10:00:00"  # longest nowcast wall clock time
      FORECASTWALLTIME="14:00:00" # forecast wall clock time
      # FIXME: no unit offset url
      ;;
      #
   "tx2020a"|"TX2020a")
      #
      INPUTDIR=$SCRIPTDIR/input/meshes/tx2020
      GRIDFILE=tx2020a.14 # mesh (fort.14) file
      MESHPROPERTIES=${GRIDFILE}.properties
      CONTROLTEMPLATE=tx2020a_esl_template.15   # fort.15 template
      # wind at 10m fort.15 template
      CONTROLTEMPLATENOROUGH=tx2020a_norough_template.15
      CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
      ELEVSTATIONS=tx2008r35h_stations_20170618.txt
      VELSTATIONS=tx2008r35h_stations_20170618.txt
      METSTATIONS=tx2008r35h_stations_20170618.txt
      NAFILE=tx2020a.13
      NAPROPERTIES=${NAFILE}.properties
      RIVERINIT=null                           # this mesh has no rivers ...
      RIVERFLUX=null
      HINDCASTRIVERFLUX=null
      # interaction between mesh and models:
      TIMESTEPSIZE=0.5           # adcirc time step size (seconds)
      SWANDT=1200                # swan timestep / coupling interval (seconds)
      # intersection between mesh, models, hpc platform, and number of compute cores:
      HINDCASTWALLTIME="24:00:00" # hindcast wall clock time
      ADCPREPWALLTIME="02:00:00"  # adcprep wall clock time, including partmesh
      NOWCASTWALLTIME="10:00:00"  # longest nowcast wall clock time
      FORECASTWALLTIME="14:00:00" # forecast wall clock time
      # FIXME: no unit offset url
      ;;
      #
   "neflga_v12_geo"|"NEFLGAv12"|"NEFLGAv12b")
      INPUTDIR=$SCRIPTDIR/input/meshes/neflga
      GRIDFILE=neflga_v12_geo.14 # mesh (fort.14) file
      MESHPROPERTIES=${GRIDFILE}.properties
      if [[ $GRIDNAME = "NEFLGAv12b" ]];  then
         GRIDFILE=neflga_v12b_geo.14 # mesh (fort.14) file
      fi
      CONTROLTEMPLATE=neflga_v12_geo_template.15   # fort.15 template
      # wind at 10m fort.15 template
      CONTROLTEMPLATENOROUGH=neflga_v12_geo_norough_template.15
      CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
      ELEVSTATIONS=neflga_stations_20190809.txt
      VELSTATIONS=${ELEVSTATIONS}
      METSTATIONS=${ELEVSTATIONS}
      NAFILE=neflga_v12.13
      NAPROPERTIES=${NAFILE}.properties
      RIVERINIT=null                           # this mesh has no rivers ...
      RIVERFLUX=null
      HINDCASTRIVERFLUX=null
      # interaction between mesh and models:
      TIMESTEPSIZE=1.0           # adcirc time step size (seconds)
      SWANDT=1200                # swan timestep / coupling interval (seconds)
      # intersection between mesh, models, hpc platform, and number of compute cores:
      HINDCASTWALLTIME="18:00:00" # hindcast wall clock time
      ADCPREPWALLTIME="02:00:00"  # adcprep wall clock time, including partmesh
      NOWCASTWALLTIME="07:00:00"  # longest nowcast wall clock time
      FORECASTWALLTIME="07:00:00" # forecast wall clock time
      # FIXME: no unit offset url
      ;;
      #
   "nc_inundation_v9.99_w_rivers"|"NCv999")
      #
      INPUTDIR=$SCRIPTDIR/input/meshes/nc_v9.99_w_rivers
      GRIDFILE=nc_inundation_v9.99a_w_rivers.grd
      MESHPROPERTIES=${GRIDFILE}.properties
      #CONTROLTEMPLATE=nc_9.99wrivers_vortex_fort.15.template
      CONTROLTEMPLATE=nc_9.99wrivers_vortex_fort.15.template.minbf.eq.0_wcap.eq.002
      # wind at 10m fort.15 template
      CONTROLTEMPLATENOROUGH=nc_9.99wrivers.nowindreduction.fort.15.template
      CONTROLPROPERTIES=fort.15.properties
      ELEVSTATIONS=ncv999_stations_20180907.txt
      VELSTATIONS=${ELEVSTATIONS}
      METSTATIONS=${ELEVSTATIONS}
      NAFILE=nc_inundation_v9.99_rivers.13
      NAPROPERTIES=${NAFILE}.properties
      RIVERINIT=v6brivers.88
      RIVERFLUX=v6brivers_fort.20_default
      HINDCASTRIVERFLUX=v6brivers_fort.20_hc_default
      # interaction between mesh and models:
      TIMESTEPSIZE=0.5           # adcirc time step size (seconds)
      SWANDT=1200                # swan timestep / coupling interval (seconds)
      # intersection between mesh, models, hpc platform, and number of compute cores:
      HINDCASTWALLTIME="18:00:00" # hindcast wall clock time
      ADCPREPWALLTIME="02:00:00"  # adcprep wall clock time, including partmesh
      NOWCASTWALLTIME="07:00:00"  # longest nowcast wall clock time
      FORECASTWALLTIME="07:00:00" # forecast wall clock time
      # unit offset url https://asgs-static-assets.sfo2.digitaloceanspaces.com/offsets/unit_offset_nc_inundation_v9.99_rivers.dat.xz
      UNITOFFSETFILE=unit_offset_nc_inundation_v9.99_rivers.dat
      ;;
   "hsofs_NE-hires_v2_depf2")
      INPUTDIR=$SCRIPTDIR/input/meshes/hsofs_NE-hires_v2_depf2/
      GRIDFILE=hsofs_NE-hires_v2_depf2.grd
      MESHPROPERTIES=${GRIDFILE}.nc.properties
      CONTROLTEMPLATE=hsofs_NE-hires_v2_depf2.15.template
      # wind at 10m fort.15 template
      CONTROLTEMPLATENOROUGH=hsofs.nowindreduction.15.template
      CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
      ELEVSTATIONS=hsofs_stations_2020-02-01.txt
      VELSTATIONS=$ELEVSTATIONS
      METSTATIONS=$ELEVSTATIONS
      NAFILE=hsofs_NE-hires_v2_with_mann_advstate.13
      NAPROPERTIES=${NAFILE}.properties
      RIVERINIT=null                          # this mesh has no rivers ...RIVERFLUX=null
      HINDCASTRIVERFLUX=null
      # interaction between mesh and models:
      TIMESTEPSIZE=0.5            # adcirc time step size (seconds)
      SWANDT=1800                 # swan timestep / coupling interval (seconds)
      # intersection between mesh, models, hpc platform, and number of compute cores:
      HINDCASTWALLTIME="24:00:00" # hindcast wall clock time
      ADCPREPWALLTIME="02:00:00"  # adcprep wall clock time, including partmesh
      NOWCASTWALLTIME="07:00:00"  # longest nowcast wall clock time
      FORECASTWALLTIME="07:00:00" # forecast wall clock time
      # unit offset url https://asgs-static-assets.sfo2.digitaloceanspaces.com/offsets/unit_offset_hsofs.dat.xz
      UNITOFFSETFILE=unit_offset_hsofs.dat
      ;;
   "hsofs"|"HSOFS")
      #
      INPUTDIR=$SCRIPTDIR/input/meshes/hsofs
      GRIDFILE=hsofs.14  # mesh (fort.14) file
      MESHPROPERTIES=${GRIDFILE}.nc.properties
      CONTROLTEMPLATE=hsofs_explicit.15.template
      # wind at 10m fort.15 template
      CONTROLTEMPLATENOROUGH=hsofs.nowindreduction.15.template
      CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
      ELEVSTATIONS=hsofs_stations_20180907.txt
      VELSTATIONS=$ELEVSTATIONS
      METSTATIONS=$ELEVSTATIONS
      NAFILE=hsofs.13
      NAPROPERTIES=${NAFILE}.properties
      RIVERINIT=null                          # this mesh has no rivers ...RIVERFLUX=null
      HINDCASTRIVERFLUX=null
      # interaction between mesh and models:
      TIMESTEPSIZE=2.0            # adcirc time step size (seconds)
      SWANDT=1800                 # swan timestep / coupling interval (seconds)
      # intersection between mesh, models, hpc platform, and number of compute cores:
      HINDCASTWALLTIME="24:00:00" # hindcast wall clock time
      ADCPREPWALLTIME="02:00:00"  # adcprep wall clock time, including partmesh
      NOWCASTWALLTIME="07:00:00"  # longest nowcast wall clock time
      FORECASTWALLTIME="07:00:00" # forecast wall clock time
      # unit offset url https://asgs-static-assets.sfo2.digitaloceanspaces.com/offsets/unit_offset_hsofs.dat.xz
      UNITOFFSETFILE=unit_offset_hsofs.dat
      ;;
   "SABv20a")
      #
      INPUTDIR=$SCRIPTDIR/input/meshes/SABv20a
      GRIDFILE=SABv20a.14  # mesh (fort.14) file
      MESHPROPERTIES=${GRIDFILE}.properties
      CONTROLTEMPLATE=SABv20a.15.template
      # wind at 10m fort.15 template
      CONTROLTEMPLATENOROUGH=SABv20a.nowindreduction.15.template
      CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
      ELEVSTATIONS=hsofs_stations_20180907.txt
      VELSTATIONS=$ELEVSTATIONS
      METSTATIONS=$ELEVSTATIONS
      NAFILE=SABv20a.13
      NAPROPERTIES=${NAFILE}.properties
      RIVERINIT=null                          # this mesh has no rivers ...RIVERFLUX=null
      HINDCASTRIVERFLUX=null
      # interaction between mesh and models:
      TIMESTEPSIZE=0.5            # adcirc time step size (seconds)
      SWANDT=1200                 # swan timestep / coupling interval (seconds)
      # intersection between mesh, models, hpc platform, and number of compute cores:
      HINDCASTWALLTIME="36:00:00" # hindcast wall clock time
      ADCPREPWALLTIME="02:00:00"  # adcprep wall clock time, including partmesh
      NOWCASTWALLTIME="24:00:00"  # longest nowcast wall clock time
      FORECASTWALLTIME="24:00:00" # forecast wall clock time
      # unit offset url
      UNITOFFSETFILE=null
      ;;
      #
   "WFLv18")
      #
      INPUTDIR=$SCRIPTDIR/input/meshes/WFLv18
      GRIDFILE=fema_wfl_fort.14  # mesh (fort.14) file
      MESHPROPERTIES=${GRIDFILE}.nc.properties
      CONTROLTEMPLATE=fema_wfl_fort.15.template
      # wind at 10m fort.15 template
      CONTROLTEMPLATENOROUGH=fema_wfl_nowindreduction.fort.15.template
      CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
      ELEVSTATIONS=fema_wfl_stations_20191114.txt
      VELSTATIONS=$ELEVSTATIONS
      METSTATIONS=$ELEVSTATIONS
      NAFILE=fema_wfl_fort.13
      NAPROPERTIES=${NAFILE}.properties
      RIVERINIT=null                          # this mesh has no rivers ...RIVERFLUX=null
      HINDCASTRIVERFLUX=null
      # interaction between mesh and models:
      TIMESTEPSIZE=1.0            # adcirc time step size (seconds)
      SWANDT=1800                 # swan timestep / coupling interval (seconds)
      # intersection between mesh, models, hpc platform, and number of compute cores:
      HINDCASTWALLTIME="24:00:00" # hindcast wall clock time
      ADCPREPWALLTIME="02:00:00"  # adcprep wall clock time, including partmesh
      NOWCASTWALLTIME="07:00:00"  # longest nowcast wall clock time
      FORECASTWALLTIME="07:00:00" # forecast wall clock time
      # unit offset url
      UNITOFFSETFILE=null
      ;;
      #
   "southfl_v11-1_final"|"SFLv111")
      #
      INPUTDIR=$SCRIPTDIR/input/meshes/southfl
      GRIDFILE=southfl_v11-1_final.grd
      MESHPROPERTIES=${GRIDFILE}.properties
      CONTROLTEMPLATE=southfl-v11-1.template.15
      # wind at 10m fort.15 template
      CONTROLTEMPLATENOROUGH=southfl-v11-1.nowindreduction.template.15
      CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
      ELEVSTATIONS=southfl_stations_20190502.txt
      VELSTATIONS=southfl_stations_20190502.txt
      METSTATIONS=southfl_stations_20190502.txt
      NAFILE=southfl_v11-1_final-production.13
      NAPROPERTIES=${NAFILE}.properties
      RIVERINIT=null                           # this mesh has no rivers ...
      RIVERFLUX=null
      HINDCASTRIVERFLUX=null
      # interaction between mesh and models:
      TIMESTEPSIZE=0.5            # adcirc time step size (seconds)
      SWANDT=1200                 # swan timestep / coupling interval (seconds)
      # intersection between mesh, models, hpc platform, and number of compute cores:
      HINDCASTWALLTIME="18:00:00" # hindcast wall clock time
      ADCPREPWALLTIME="02:00:00"  # adcprep wall clock time, including partmesh
      NOWCASTWALLTIME="07:00:00"  # longest nowcast wall clock time
      FORECASTWALLTIME="07:00:00" # forecast wall clock time
      # FIXME: no unit offset url
      ;;
      #
   "CenFlv7"|"eccl_v7_geo_z")
      #
      INPUTDIR=$SCRIPTDIR/input/meshes/cenfl
      GRIDFILE=eccl_v7_geo_z.grd
      MESHPROPERTIES=${GRIDFILE}.properties
      CONTROLTEMPLATE=cenfl.fort.15.template
      # wind at 10m fort.15 template
      CONTROLTEMPLATENOROUGH=cenfl.norough.fort.15.template
      CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
      ELEVSTATIONS=cenfl_stations_20190809.txt
      VELSTATIONS=${ELEVSTATIONS}
      METSTATIONS=${ELEVSTATIONS}
      NAFILE=cenfl_v7.13
      NAPROPERTIES=${NAFILE}.properties
      RIVERINIT=null                           # this mesh has no rivers ...
      RIVERFLUX=null
      HINDCASTRIVERFLUX=null
      # interaction between mesh and models:
      TIMESTEPSIZE=1.0            # adcirc time step size (seconds)
      SWANDT=1200                 # swan timestep / coupling interval (seconds)
      # intersection between mesh, models, hpc platform, and number of compute cores:
      HINDCASTWALLTIME="18:00:00" # hindcast wall clock time
      ADCPREPWALLTIME="02:00:00"  # adcprep wall clock time, including partmesh
      NOWCASTWALLTIME="07:00:00"  # longest nowcast wall clock time
      FORECASTWALLTIME="07:00:00" # forecast wall clock time
      # FIXME: no unit offset url
      ;;
      #
   "FEMAR3")
      #
      INPUTDIR=$SCRIPTDIR/input/meshes/femar3
      GRIDFILE=FEMA_R3_20110303_MSL.grd
      MESHPROPERTIES=${GRIDFILE}.properties
      CONTROLTEMPLATE=FEMA_R3_fort.15.template
      # wind at 10m fort.15 template
      CONTROLTEMPLATENOROUGH=FEMA_R3_nowindreduction_fort.15.template
      CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
      ELEVSTATIONS=cera_stations_20180810.txt
      VELSTATIONS=${ELEVSTATIONS}
      METSTATIONS=${ELEVSTATIONS}
      NAFILE=FEMA_R3_20110303_MSL.13
      NAPROPERTIES=${NAFILE}.properties
      RIVERINIT=null                           # this mesh has no rivers ...
      RIVERFLUX=null
      HINDCASTRIVERFLUX=null
      # interaction between mesh and models:
      TIMESTEPSIZE=1.0            # adcirc time step size (seconds)
      SWANDT=1200                 # swan timestep / coupling interval (seconds)
      # intersection between mesh, models, hpc platform, and number of compute cores:
      HINDCASTWALLTIME="18:00:00" # hindcast wall clock time
      ADCPREPWALLTIME="02:00:00"  # adcprep wall clock time, including partmesh
      NOWCASTWALLTIME="07:00:00"  # longest nowcast wall clock time
      FORECASTWALLTIME="07:00:00" # forecast wall clock time
      # https://asgs-static-assets.sfo2.digitaloceanspaces.com/offsets/unit_offset_FEMA_R3_20110303_MSL.dat.xz
      UNITOFFSETFILE=unit_offset_FEMA_R3_20110303_MSL.dat
      ;;
      #
   "FEMAR2")
      #
      INPUTDIR=$SCRIPTDIR/input/meshes/femar2
      GRIDFILE=FEMA_R2_norivers_gcs_mNAVD.grd
      MESHPROPERTIES=${GRIDFILE}.properties
      CONTROLTEMPLATE=FEMA_R2_fort.15.template
      # wind at 10m fort.15 template
      CONTROLTEMPLATENOROUGH=FEMA_R2.noswanrefrac.nowindreduction.fort.15.template
      CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
      ELEVSTATIONS=cera_stations_20180810.txt
      VELSTATIONS=${ELEVSTATIONS}
      METSTATIONS=${ELEVSTATIONS}
      NAFILE=FEMA_R2_01262012_refrac_fort.13
      NAPROPERTIES=${NAFILE}.properties
      RIVERINIT=null                           # this mesh has no rivers ...
      RIVERFLUX=null
      HINDCASTRIVERFLUX=null
      # interaction between mesh and models:
      TIMESTEPSIZE=1.0            # adcirc time step size (seconds)
      SWANDT=1200                 # swan timestep / coupling interval (seconds)
      # intersection between mesh, models, hpc platform, and number of compute cores:
      HINDCASTWALLTIME="18:00:00" # hindcast wall clock time
      ADCPREPWALLTIME="02:00:00"  # adcprep wall clock time, including partmesh
      NOWCASTWALLTIME="07:00:00"  # longest nowcast wall clock time
      FORECASTWALLTIME="07:00:00" # forecast wall clock time
      # no scalable unit water level correction file
      ;;
      #
   "NAC2014")
      #
      INPUTDIR=$SCRIPTDIR/input/meshes/naccs
      GRIDFILE=NAC2014_R01_ClosedRivers.grd
      MESHPROPERTIES=${GRIDFILE}.properties
      CONTROLTEMPLATE=NAC2014_R01.15.template
      # wind at 10m fort.15 template
      CONTROLTEMPLATENOROUGH=NAC2014_R01.nowindreduction.15.template
      CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
      ELEVSTATIONS=cera_stations_20180810.txt
      VELSTATIONS=${ELEVSTATIONS}
      METSTATIONS=${ELEVSTATIONS}
      NAFILE=NAC2014_R01.13
      NAPROPERTIES=${NAFILE}.properties
      RIVERINIT=null                           # this mesh has no rivers ...
      RIVERFLUX=null
      HINDCASTRIVERFLUX=null
      # interaction between mesh and models:
      TIMESTEPSIZE=1.0            # adcirc time step size (seconds)
      SWANDT=1200                 # swan timestep / coupling interval (seconds)
      # intersection between mesh, models, hpc platform, and number of compute cores:
      HINDCASTWALLTIME="18:00:00" # hindcast wall clock time
      ADCPREPWALLTIME="02:00:00"  # adcprep wall clock time, including partmesh
      NOWCASTWALLTIME="07:00:00"  # longest nowcast wall clock time
      FORECASTWALLTIME="07:00:00" # forecast wall clock time
      # no scalable unit water level correction file
      ;;
      #
   "NGOMv19b")
      #
      INPUTDIR=${SCRIPTDIR}/input/meshes/NGOMv19b # grid and other input files
      GRIDFILE=NGOM_RT_v19b_chk.grd
      MESHPROPERTIES=${GRIDFILE}.properties
      CONTROLTEMPLATE=NGOM_RT_v19b.15.template_18kcms   # fort.15 template
      # wind at 10m fort.15 template
      CONTROLTEMPLATENOROUGH=NGOM_RT_v19b.nowindreduction.15.template
      CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
      ELEVSTATIONS=NGOM_RT_v19b_stations_08282018.txt
      VELSTATIONS=NGOM_RT_v19b_stations_08282018.txt
      METSTATIONS=NGOM_RT_v19b_stations_08282018.txt
      NAFILE=NGOM_RT_v19b_chk.13
      NAPROPERTIES=${NAFILE}.properties
      RIVERINIT=null                           # this mesh has no rivers ...
      RIVERFLUX=null
      HINDCASTRIVERFLUX=null
      # interaction between mesh and models:
      TIMESTEPSIZE=1.0           # adcirc time step size (seconds)
      SWANDT=1200                 # swan time step size (seconds)
      # intersection between mesh, models, hpc platform, and number of compute cores:
      HINDCASTWALLTIME="18:00:00" # hindcast wall clock time
      ADCPREPWALLTIME="01:00:00"  # adcprep wall clock time, including partmesh
      NOWCASTWALLTIME="10:00:00"  # longest nowcast wall clock time
      FORECASTWALLTIME="07:00:00" # forecast wall clock time
      UNITOFFSETFILE=oi_surface_NGOM_RT_v19b_chk.grd.dat
      ;;
      #
      #
   "EGOMv20b")
      #
      INPUTDIR=${SCRIPTDIR}/input/meshes/EGOMv20b # grid and other input files
      GRIDFILE=EGOM-RT_v20b_chk.grd
      MESHPROPERTIES=${GRIDFILE}.properties
      CONTROLTEMPLATE=EGOM-RT_v20b.15.template   # fort.15 template
      # wind at 10m fort.15 template
      CONTROLTEMPLATENOROUGH=EGOM-RT_v20b.norough.15.template
      CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
      ELEVSTATIONS=EGOM-RT_v20b_stations.txt
      VELSTATIONS=EGOM-RT_v20b_stations.txt
      METSTATIONS=EGOM-RT_v20b_stations.txt
      NAFILE=EGOM-RT_v20b_asgs_chk.13
      NAPROPERTIES=${NAFILE}.properties
      RIVERINIT=null                            # this mesh has no rivers ...
      RIVERFLUX=null
      HINDCASTRIVERFLUX=null
      # interaction between mesh and models:
      TIMESTEPSIZE=1.0           # adcirc time step size (seconds)
      SWANDT=1200                 # swan time step size (seconds)
      # intersection between mesh, models, hpc platform, and number of compute cores:
      HINDCASTWALLTIME="18:00:00" # hindcast wall clock time
      ADCPREPWALLTIME="01:00:00"  # adcprep wall clock time, including partmesh
      NOWCASTWALLTIME="10:00:00"  # longest nowcast wall clock time
      FORECASTWALLTIME="07:00:00" # forecast wall clock time
      # FIXME: no unit offset url
      ;;
      #
   "Shinnecock")
      #
      INPUTDIR=${SCRIPTDIR}/input/meshes/shinnecock # grid and other input files
      GRIDFILE=shinnecock_inlet_coarse.grd
      MESHPROPERTIES=${GRIDFILE}.properties
      CONTROLTEMPLATE=shinnecock_asgs.fort.15.template
      # wind at 10m fort.15 template
      CONTROLTEMPLATENOROUGH=shinnecock_asgs.fort.15.template
      CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
      ELEVSTATIONS=shinnecock_stations.txt
      VELSTATIONS=$ELEVSTATIONS
      METSTATIONS=$ELEVSTATIONS
      NAFILE=null
      NAPROPERTIES=shinnecock_nodal_attributes.properties
      RIVERINIT=null                            # this mesh has no rivers ...
      RIVERFLUX=null
      HINDCASTRIVERFLUX=null
      # interaction between mesh and models:
      TIMESTEPSIZE=6.0           # adcirc time step size (seconds)
      SWANDT=1200                 # swan time step size (seconds)
      # intersection between mesh, models, hpc platform, and number of compute cores:
      HINDCASTWALLTIME="01:00:00" # hindcast wall clock time
      ADCPREPWALLTIME="01:00:00"  # adcprep wall clock time, including partmesh
      NOWCASTWALLTIME="01:00:00"  # longest nowcast wall clock time
      FORECASTWALLTIME="01:00:00" # forecast wall clock time
      # FIXME: no unit offset url
      ;;
   "ec2001_v2e"|"EC2001v2e")
      #
      INPUTDIR=$SCRIPTDIR/input/meshes/EC2001
      GRIDFILE=ec2001_v2e.grd   # mesh (fort.14) file
      MESHPROPERTIES=${GRIDFILE}.properties
      CONTROLTEMPLATE=ec2001_v2e_fort.15.template   # fort.15 template (designed for 1s timestep)
      TIMESTEPSIZE=1.0           # adcirc time step size (seconds)
      # CONTROLTEMPLATE=ec2001_v2e_adcircv55_fort.15.template # designed for larger timestep (e.g., 50s)
      # TIMESTEPSIZE=50.0
      # wind at 10m fort.15 template
      CONTROLTEMPLATENOROUGH=$CONTROLTEMPLATE  # same b/c no inundation coverage
      CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
      ELEVSTATIONS=hsofs_stations_20180907.txt
      VELSTATIONS=$ELEVSTATIONS
      METSTATIONS=$ELEVSTATIONS
      NAFILE=ec2001_v2e.13
      NAPROPERTIES=${NAFILE}.properties
      RIVERINIT=null                            # this mesh has no rivers ...
      RIVERFLUX=null
      HINDCASTRIVERFLUX=null
      # interaction between mesh and models:
      SWANDT=1200                # swan timestep / coupling interval (seconds)
      # intersection between mesh, models, hpc platform, and number of compute cores:
      HINDCASTWALLTIME="06:00:00" # hindcast wall clock time
      ADCPREPWALLTIME="01:00:00"  # adcprep wall clock time, including partmesh
      NOWCASTWALLTIME="01:00:00"  # longest nowcast wall clock time
      FORECASTWALLTIME="01:00:00" # forecast wall clock time
      UNITOFFSETFILE=null
      ;;
   "OPENWATERv1e")
      #
      INPUTDIR=$SCRIPTDIR/input/meshes/OPENWATER
      GRIDFILE=openwater.grd  # mesh (fort.14) file
      MESHPROPERTIES=${GRIDFILE}.properties
      CONTROLTEMPLATE=openwater.fort.15.template  # designed for 2s timestep (any adcirc version)
      TIMESTEPSIZE=2.0            # adcirc time step size (seconds)
      # CONTROLTEMPLATE=openwater_adcircv55.fort.15.template # designed for larger timestep (adcirc v55 only)
      # TIMESTEPSIZE=50.0            # adcirc time step size (seconds)
      # wind at 10m fort.15 template
      CONTROLTEMPLATENOROUGH=${CONTROLTEMPLATE} # same b/c no inundation area
      CONTROLPROPERTIES=${CONTROLTEMPLATE}.properties
      ELEVSTATIONS=hsofs_stations_20180907.txt
      VELSTATIONS=$ELEVSTATIONS
      METSTATIONS=$ELEVSTATIONS
      NAFILE=openwater.13
      NAPROPERTIES=${NAFILE}.properties
      RIVERINIT=null                          # this mesh has no rivers ...RIVERFLUX=null
      HINDCASTRIVERFLUX=null
      # interaction between mesh and models:
      TIMESTEPSIZE=2.0            # adcirc time step size (seconds)
      SWANDT=1800                 # swan timestep / coupling interval (seconds)
      # intersection between mesh, models, hpc platform, and number of compute cores:
      HINDCASTWALLTIME="24:00:00" # hindcast wall clock time
      ADCPREPWALLTIME="02:00:00"  # adcprep wall clock time, including partmesh
      NOWCASTWALLTIME="07:00:00"  # longest nowcast wall clock time
      FORECASTWALLTIME="07:00:00" # forecast wall clock time
      UNITOFFSETFILE=null
      ;;
   *)
      warn "cycle $CYCLE: $SCENARIO: $THIS: Mesh GRIDNAME $GRIDNAME was not recognized."
      ;;
esac
