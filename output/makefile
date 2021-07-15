#--------------------------------------------------------------------------
# makefile
#
# A system to build ASGS-related utilities for processing ADCIRC output.
#
#--------------------------------------------------------------------------
# Copyright(C) 2014--2019 Jason Fleming
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
#--------------------------------------------------------------------------
#
# This makefile contains support for several different machines, but perhaps
# not yours, although that will be easy to add. All you have to do is add a
# line that shows where the netCDF library is installed.
#
# For example, have a look at the following lines for the queenbee machine:
#
#  ifeq ($(MACHINENAME),queenbee)
#      NETCDFPATH  := /usr/local/packages/netcdf/4.2.1.1/INTEL-140-MVAPICH2-2.0
#  endif
#
# In order to support your machine, you'll have to add something similar to
# define the NETCDFPATH variable. I do this by typing
#
# which ncdump
#
# and that gives me an answer like
#
# /usr/local/packages/netcdf/4.2.1.1/INTEL-140-MVAPICH2-2.0/bin
#
# so I set the NETCDFPATH to that but without the "/bin" at the end.
# Then I compile by using the following command line:
#
#  make netcdf2adcirc compiler=intel MACHINENAME=queenbee NETCDF=enable NETCDF4=enable NETCDF4_COMPRESSION=enable
#
#
# specify compiler=gfortran on the make command line
ifeq ($(compiler),gfortran)
   FC := gfortran
   FFLAGS := -O2 -cpp -ffree-line-length-none
   ifeq ($(DEBUG),full)
      FFLAGS := -cpp -ffree-line-length-none -g -O0 -fbacktrace -fbounds-check -ffpe-trap=zero,invalid,underflow,overflow,denormal -DDEBUGSEGFAULT
   endif
   ifeq ($(DEBUG),trace)
      FFLAGS := -cpp -ffree-line-length-none -g -O0 -fbacktrace
   endif
   ifeq ($(MACHINENAME),jason-desktop)
      FFLAGS := $(FFLAGS) -DOLDGFORTRAN
   endif
   ifeq ($(MACHINENAME),vagrant)
      FFLAGS := $(FFLAGS) -DOLDGFORTRAN
   endif
   ifeq ($(MACHINENAME),docker)
      FFLAGS := $(FFLAGS) -DOLDGFORTRAN
   endif
   ifeq ($(DEBUG),trace)
      FFLAGS := -cpp -ffree-line-length-none -g -O0 -fbacktrace
   endif
endif
#
# specify compiler=intel on the make command line
#
# For ifort 13.0.0 add -heap-arrays flag to prevent segmentation fault
# due possible compiler bug. Flag not needed for ifort version 13.1.3 and later. -nld
ifeq ($(compiler),intel)
   FC := ifort
   FFLAGS := -cpp -shared-intel -DINTEL
   ifeq ($(DEBUG),trace)
      FFLAGS := -g -O0 -fpp -traceback
   endif
   ifeq ($(DEBUG),full)
      FFLAGS := -cpp -g -O0 -traceback -debug all -check all -ftrapuv -fpe0 -shared-intel -DDEBUGSEGFAULT
   endif
   # jgf20150616: Added to implement nld's -heap-arrays fix.
   ifeq ($(HEAP_ARRAYS),fix)
      FFLAGS := $(FFLAGS) -heap-arrays
   endif
endif
#
# specify compiler=pgf90 on make command line
ifeq ($(compiler),pgf90)
   FC := pgf90
   FFLAGS := -Mpreprocess -Mextend -Minform,inform -tp=shanghai-64 -fast
   ifeq ($(DEBUG),full)
      FFLAGS := -Mextend -g -O0 -traceback -Mbounds -Mchkfpstk -Mchkptr -Mchkstk -DALL_TRACE -DFLUSH_MESSAGES -DFULL_STACK -tp=shanghai-64 -DDEBUGSEGFAULT
   endif
endif
#
INCLUDES := -I.
#
# if netcdf libraries are available on the target platform,
# use NETCDF=enable on the make command line
ifeq ($(NETCDF),enable)
   FFLAGS      := $(FFLAGS) -DASGSNETCDF
   NETCDFPATH  := /usr
   #
   # jgf20150616: Added netcdf paths for stampede at TACC.
   ifeq ($(MACHINENAME),stampede2)
      NETCDFPATH := /opt/apps/intel17/netcdf/4.3.3.1/x86_64
      ifeq ($(USER),jgflemin)
         NETCDFPATH  := $(WORK)/local
         LIBS        := -L$(WORK)/local/lib
         LDFLAGS     :=  -lnetcdf -lnetcdff
      endif
   endif
   # jgf20150716: Added compiler flags for hatteras at RENCI.
   ifeq ($(MACHINENAME),hatteras)
      #NETCDFPATH  := /usr/share/Modules/software/RHEL-6.5/netcdf/netcdf-4.1.3_intel-14.0.3
      # jgf20180105
      NETCDFPATH := $(shell nf-config --prefix)
   endif
   # jgf20190624: Added compiler flags for locally compiled netcdf on hatteras at RENCI.
   ifeq ($(MACHINENAME),hatteras-local)
      NETCDFPATH := /home/ncfs/local
   endif
   # nld20170829: Added compiler flags for seadog at Ransom.
   ifeq ($(MACHINENAME),seadog)
      NETCDFPATH  := /home/nate/install
   endif
   # jgf20150720: Added compiler flags for queenbee at LONI.
   ifeq ($(MACHINENAME),queenbee)
      NETCDFPATH  := /usr/local/packages/netcdf/4.2.1.1/INTEL-140-MVAPICH2-2.0
   endif
   # jgf20150720: Added compiler flags for queenbee at LONI.
   ifeq ($(MACHINENAME),supermic)
      NETCDFPATH  := /usr/local/packages/netcdf/4.2.1.1/INTEL-140-MVAPICH2-2.0
      LDFLAGS     :=  -lnetcdf
   endif
   # jgf20150817: Added compiler flags for garnet at ERDC.
   ifeq ($(MACHINENAME),garnet)
      NETCDFPATH  := /opt/cray/netcdf/4.3.0/pgi/121
   endif
   # jgf20160428: Added compiler flags for topaz at ERDC.
   ifeq ($(MACHINENAME),topaz)
      NETCDFPATH  := /apps/unsupported/netcdf/4.3.3.1-intel-15.0.3
   endif
   # jgf20150817: Added compiler flags for spirit at AFRL.
   ifeq ($(MACHINENAME),spirit)
      NETCDFPATH  := /app/wpostool/COST/netcdf-fortran-4.4.2/intel
      LIBS        := -L/app/wpostool/COST/netcdf-c-4.3.1.1/intel/lib -L/app/wpostool/COST/hdf5-mpi/1.8.12/intel/sgimpt/lib
      LDFLAGS     :=  -lnetcdf -lhdf5 -lhdf5_hl
   endif
   ifeq ($(MACHINENAME),poseidon)
      NETCDFPATH  := /home/fhrl/Documents/Surge/scripts/netcdf
      LIBS        := -L/home/fhrl/Documents/Surge/scripts/netcdf/lib
      LDFLAGS     :=  -lnetcdf
   endif
   # jgf20160627: Added compiler flags for lonestar 5 at TACC.
   # jgf20160803: Updated compiler flags for lonestar 5 at TACC.
   # jgf20190406: Updated compiler flags for lonestar 5 at TACC.
   ifeq ($(MACHINENAME),lonestar)
      #NETCDFPATH=/opt/apps/intel16/netcdf/4.3.3.1/x86_64
      NETCDFPATH=/opt/apps/intel18/netcdf/4.6.2/x86_64
   endif
   ifeq ($(MACHINENAME),mike)
      NETCDFPATH := /home/nate/install
   endif
   ifeq ($(MACHINENAME),JDB_MacPro)
      NETCDFPATH := /usr/local/Cellar/netcdf/4.6.2_1
   endif
   ifeq ($(MACHINENAME),penguin)
      NETCDFPATH := /home/jgflemin/local
   endif
   FFLAGS      := $(FFLAGS) -DASGSNETCDF
   LDFLAGS     := $(LDFLAGS) -lnetcdff
   INCLUDES    := -I. -I$(NETCDFPATH)/include
   LIBS        := $(LIBS) -L$(NETCDFPATH)/lib
endif
ifeq ($(NETCDF4),enable)
   FFLAGS      := $(FFLAGS) -DHAVE_NETCDF4
endif
ifeq ($(NETCDF4_COMPRESSION),enable)
   FFLAGS      := $(FFLAGS) -DNETCDF_CAN_DEFLATE
endif
#
#
OBJ := adcmesh.o asgsio.o nodalattr.o logging.o
# JDB March 2019, added ioutil.mod to MODS
MODS := ioutil.mod adcmesh.mod asgsio.mod nodalattr.mod logging.mod
#
# targets
all : adcirc2netcdf netcdf2adcirc makeMax generateXDMF pullStationTimeSeries generateCPP inundationMask HottifySWAN checkAdcircMesh resultScope highResolutionRegion stationProcessor collectMinMax addMeshToNetCDF
#
clean :
	rm -f *.o *.mod *.x FigureGen/*.mod FigureGen/*.x
#
#
addMeshToNetCDF : $(MODS) addMeshToNetCDF.f90 logging.mod
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -o $@.x $@.f90 $(OBJ) $(LDFLAGS)
# FIXME: make FigureGen is not working yet
FigureGen : FigureGen/FigureGen.F90
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -o $@/$@.x $@/$@.F90 $(LDFLAGS)
#
adcirc2netcdf : $(MODS) adcirc2netcdf.f90 nodalattr.mod logging.mod
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -o $@.x $@.f90 $(OBJ) $(LDFLAGS)
#
netcdf2adcirc : $(MODS) netcdf2adcirc.f90
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -o $@.x $@.f90 $(OBJ) $(LDFLAGS)
#
asgsio.mod : logging.mod ioutil.mod adcmesh.mod nodalattr.mod asgsio.f90
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -c asgsio.f90 $(LDFLAGS)
#
adcmesh.mod : adcmesh.f90 logging.mod
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -c adcmesh.f90 $(LDFLAGS)
#
logging.mod : logging.f90
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -c logging.f90 $(LDFLAGS)
#
ioutil.mod : logging.f90
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -c logging.f90 $(LDFLAGS)
#
makeMax : asgsio.mod adcmesh.mod ../util/makeMax.f90
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -o ../util/$@.x ../util/$@.f90 $(OBJ) $(LDFLAGS)
#
inundationMask : $(MODS) inundationMask.f90
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -o $@.x $@.f90 $(OBJ) $(LDFLAGS)
#
highResolutionRegion : adcmesh.mod highResolutionRegion.f90
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -o $@.x $@.f90 $(OBJ) $(LDFLAGS)
#
checkAdcircMesh : $(MODS) checkAdcircMesh.f90
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -o $@.x $@.f90 $(OBJ) $(LDFLAGS)
#
generateXDMF : adcmesh.mod asgsio.mod logging.mod nodalattr.mod generateXDMF.f90
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -o $@.x $@.f90 adcmesh.o asgsio.o logging.o nodalattr.o $(LDFLAGS)
#
generateCPP : adcmesh.mod generateCPP.f90
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -o $@.x $@.f90 $(OBJ) $(LDFLAGS)
#
pullStationTimeSeries : asgsio.mod adcmesh.mod nodalattr.mod pullStationTimeSeries.f90
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -o $@.x $@.f90 $(OBJ) $(LDFLAGS)
#
stationProcessor : asgsio.mod adcmesh.mod nodalattr.mod stationProcessor.f90
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -o $@.x $@.f90 asgsio.o adcmesh.o logging.o nodalattr.o $(LDFLAGS)
#
wetDryCheck : adcmesh.mod asgsio.mod wetDryCheck.f90
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -o $@.x $@.f90 adcmesh.o asgsio.o $(LDFLAGS)
#
diffAdcircNetCDF : adcmesh.mod asgsio.mod diffAdcircNetCDF.f90
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -o $@.x $@.f90 adcmesh.o asgsio.o $(LDFLAGS)
#
HottifySWAN : HottifySWAN.F90
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -o $@.x $@.F90 $(LDFLAGS)
#
collectMinMax : adcmesh.mod asgsio.mod collectMinMax.f90
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -o $@.x $@.f90 $(OBJ) $(LDFLAGS)

resultScope : adcmesh.mod asgsio.mod resultScope.f90
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -o $@.x $@.f90 $(OBJ) $(LDFLAGS)
#
nodalattr.mod : ../util/input/nodalattr/nodalattr.f90 adcmesh.mod
	$(FC) $(FFLAGS) $(INCLUDES) $(LIBS) -c ../util/input/nodalattr/nodalattr.f90 $(LDFLAGS)
