#!/bin/bash

OPT=${1-$HOME/opt}
COMPILER=${2-gfortran}
JOBS=${3-1}
TMP=/tmp/$USER-asgs

OPENMPI_MAJOR_VERSION=1.8
OPENMPI_MINOR_VERSION=1
OPENMPI_FULL_VERSION=openmpi-${OPENMPI_MAJOR_VERSION}.${OPENMPI_MINOR_VERSION}

if [ $2 == "clean" ]; then 
  COMPILER=gfortran
  echo Cleaning OpenMPI libraries and utilities
  cd $OPT/$COMPILER/bin
  rm -rfv mpic++ mpic++-vt mpif77-vt mpirun ompi-top orted orte-top otfaux  otfmerge otfshrink vtcc vtfilter  vtrun mpicc mpicxx mpif90 ompi-clean opal_wrapper orte-info oshcc otfcompress otfmerge-mpi shmemcc vtCC vtfiltergen vtunify mpiCC mpicxx-vt mpif90-vt ompi_info opari  orte-ps oshfort otfconfig otfprint shmemfort vtcxx vtfiltergen-mpi vtunify-mpi mpicc-vt mpiexec mpifort ompi-ps ortecc orterun oshmem_info otfdecompress otfprofile shmemrun vtf77 vtfilter-mpi vtwrapper mpiCC-vt mpif77 mpifort-vt ompi-server orte-clean orte-server oshrun otfinfo otfprofile-mpi vtc++ vtf90 vtfort
  cd $OPT/$COMPILER/lib
 rm -rfv libmca_common_sm.la libmpi_mpifh.so libompitrace.la libopen-rte.so.7 liboshmem.so.1.0.0 libvt-hyb.so.0 libvt-mpi-unify.so libvt.so libmca_common_sm.so libmpi_mpifh.so.2 libompitrace.so libopen-rte.so.7.0.3 libotfaux.a libvt-hyb.so.0.0.0 libvt-mpi-unify.so.0 libvt.so.0 libmca_common_sm.so.4 libmpi_mpifh.so.2.3.0 libompitrace.so.0 libopen-trace-format.a libotfaux.la libvt.la libvt-mpi-unify.so.0.0.0 libvt.so.0.0.0 libmca_common_sm.so.4.0.3 libmpi.so libompitrace.so.0.0.0 libopen-trace-format.la libotfaux.so libvt-mpi.a libvt-mt.a mpi.mod libmpi_cxx.la libmpi.so.1 libopen-pal.la libopen-trace-format.so libotfaux.so.0 libvt-mpi.la libvt-mt.la openmpi libmpi_cxx.so libmpi.so.1.5.0 libopen-pal.so libopen-trace-format.so.1 libotfaux.so.0.0.0 libvt-mpi.so libvt-mt.so pkgconfig libmpi_cxx.so.1 libmpi_usempi.la libopen-pal.so.6 libopen-trace-format.so.1.0.0 libvt.a libvt-mpi.so.0 libvt-mt.so.0 libmpi_cxx.so.1.1.3 libmpi_usempi.so libopen-pal.so.6.1.1 liboshmem.la  libvt-hyb.a libvt-mpi.so.0.0.0 libvt-mt.so.0.0.0 libmpi.la  libmpi_usempi.so.1 libopen-rte.la liboshmem.so  libvt-hyb.la libvt-mpi-unify.a libvt-pomp.a libmpi_mpifh.la libmpi_usempi.so.1.3.0 libopen-rte.so liboshmem.so.1  libvt-hyb.so libvt-mpi-unify.la libvt-pomp.la
  cd $OPT/$COMPILER/include
  rm -rfv mpi-ext.h mpif-constants.h mpif-ext.h mpif-handles.h mpif-io-handles.h mpi.h mpp shmem.fh vampirtrace mpif-config.h mpif-externals.h mpif.h mpif-io-constants.h mpif-sentinels.h mpi_portable_platform.h openmpi shmem.h
  exit
fi

if [ $COMPILER == "intel" ]; then 
  export CC=icc
  export FC=ifort
  export CXX=icpc
  echo "--prefix adjusted to $OPT"
fi
if [ $COMPILER == "gfortran" ]; then 
  export CC=gcc
  export FC=gfortran
  export FFLAGS=${FFLAGS}
  export CXX=g++
fi
OPT=${OPT}/$COMPILER
echo "--prefix adjusted to $OPT"

mkdir -p $TMP 2> /dev/null
chmod 700 $TMP

if [ ! -d $OPT ]; then
  mkdir -p $OPT
else
  if [ -e $OPT/bin/mpif77 ]; then
    echo Looks like OpenMPI has been built
    exit 0  
  fi
fi
cd $TMP

if [ ! -e ${OPENMPI_FULL_VERSION}.tar.gz ]; then 
  wget https://www.open-mpi.org/software/ompi/v${OPENMPI_MAJOR_VERSION}/downloads/${OPENMPI_FULL_VERSION}.tar.gz
else
  echo Found $TMP/${OPENMPI_FULL_VERSION}.tar.gz
  rm -rf ./${OPENMPI_FULL_VERSION} >/dev/null 2>&1
fi
tar -xvf $OPENMPI_FULL_VERSION.tar.gz
cd $OPENMPI_FULL_VERSION 

./configure --prefix=$OPT --disable-oshmem-fortran --disable-oshmem --disable-vt --disable-libompitrace --disable-io-romio --disable-debug-symbols --disable-io-ompio
make -j $JOBS
make -j $JOBS install
