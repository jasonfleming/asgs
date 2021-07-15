!--------------------------------------------------------------------------
! generateXDMF.f90
!
! A program to generate XDMF xml for NetCDF4 formatted ADCIRC files.
!
!--------------------------------------------------------------------------
! Copyright(C) 2012--2019 Jason Fleming
!
! This file is part of the ADCIRC Surge Guidance System (ASGS).
!
! The ASGS is free software: you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation, either version 3 of the License, or
! (at your option) any later version.
!
! ASGS is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License
! along with the ASGS.  If not, see <http://www.gnu.org/licenses/>.
!--------------------------------------------------------------------------
! Compile this program with the accompanying makefile.
!--------------------------------------------------------------------------
program generateXDMF
use netcdf
use ioutil
use logging
use asgsio
use adcmesh
use nodalattr
implicit none
integer :: iargc
character(len=20) :: logLevelOpt
logical :: setLogLevel = .false.
!
type(mesh_t) :: m
type(meshNetCDF_t) :: n
!
#ifdef OLDGFORTRAN
! gfortran v4.6.3 (2011) chokes on an allocatable array of fileMetaData_t
type(fileMetaData_t) :: fileMetaData(10)
#else
type(fileMetaData_t), allocatable :: fileMetaData(:)
#endif
!
logical :: fileFound = .false.
integer :: iSnap    ! snapshot counter
integer :: numFiles ! number of data files to refer to from the xml file
integer :: fi       ! file counter
integer :: olun     ! i/o unit number where xdmf xml will be written
!
! NetCDF related variables
integer :: ncStatus
integer :: ncformat ! whether netcdf 3 or netcdf 4
character(NF90_MAX_NAME) :: thisVarName ! netcdf variable names
!
! XDMF XML related variables.
character(2048) :: xdmfFile ! netcdf variable names
!
! Maureparticle variables
integer :: partID ! particle ID    (temp variable)
real(8) :: lon ! particle longitude (temp variable)
real(8) :: lat ! particle latitude (temp variable)
real(8) :: timesec ! time in seconds corresponding to a particular snap (temp variable)
real(8) :: oldtimesec ! time in seconds corresponding to a particular snap
integer :: ele ! element number where a particle is found (temp variable)
integer :: particleCount = 0
integer :: numParticlesSpecified = 0   ! operator-specified max number of particles
integer :: numParticleDatasetsSpecified = 0 ! operator specified number of particle snaps
real(8) :: particleTimeSec = 0 ! time (sec) associated with a particular particle dataset
real(8) :: particleStartTimeSec = 0  ! time (sec) of the first particle dataset
real(8) :: particleDatasetTimeIncrement = 0 ! time (sec) between particle datasets
integer :: lineNum = 1 ! line about to be read from Maureparticle file
integer :: numLines ! total number of lines in the Maureparticle file
integer :: maureIndex ! index of the maureparticle file
logical :: writeParticleFile = .false. ! true if the xdmf file is for particles
type(station_t), allocatable :: particles(:)
integer, parameter :: MAX_DATASETS = 1e8
integer, allocatable :: numParticles(:) ! temporarily hold number of particles per dataset
integer, allocatable :: pTimesec(:) ! temporarily hold time stamp of particle datasets in seconds
logical :: meshInitialized = .false. ! true if the associated mesh has been read in
logical :: meshOnly = .false. ! true if only the mesh xml will be written
logical :: allTimeInvariant ! true if all the files are static
logical :: getNodeIndices = .false. ! true if dataset of 1-indexed node array indices should be added to xml
logical :: getElementIndices = .false. ! true if dataset of 1-indexed element array indices should be added to xml
!
integer :: errorIO
integer oldnp ! used to detect differences in number of nodes between data files
integer oldne ! used to detect differences in number of elements between data files
integer :: nSnaps ! number of snapshots in the time varying files (must all be the same)
integer :: i, j ! loop counters
integer :: ds   ! dataset loop counter
!
xdmfFile = 'null'
numFiles = 0
argcount = iargc() ! count up command line options
if (argcount.gt.0) then
   ! count the number of files for processing
   i=0
   do while (i.lt.argcount)
      i = i + 1
      call getarg(i, cmdlineopt)
      select case(trim(cmdlineopt))
         case("--logfile")
            i = i + 1
            call getarg(i, cmdlinearg)
            call initLogging(availableUnitNumber(),'generateXDMF.f90',trim(cmdlinearg))
            write(scratchMessage,'(a,a,a,a,a)') 'Processing "',trim(cmdlineopt),' ',trim(cmdlinearg),'".'
            call allMessage(INFO,scratchMessage)
         case("--loglevel")
            i = i + 1
            call getarg(i, loglevelopt)
            write(scratchMessage,'(a,a,a,a,a)') 'Processing "',trim(cmdlineopt),' ',trim(cmdlinearg),'".'
            call allMessage(INFO,scratchMessage)
            setLogLevel = .true.
         case("--datafile","--maureparticle")
            numFiles = numFiles + 1
         case default
            ! skip it
      end select
   end do
   ! init logging if not already done
   if (loggingInitialized.eqv..false.) then
      call initLogging(availableUnitNumber(),'generateXDMF.f90')
   endif
   if (setLogLevel.eqv..true.) then
      call setLoggingLevel(loglevelopt)
   endif
   ! allocate space to hold metadata for each of the data files
   ! we will refer to
   if (numFiles.eq.0) then
      call allMessage(ERROR,'Must specify at least one data file with "--datafile ...".')
   endif
#ifndef OLDGFORTRAN
   ! gfortran v4.6.3 (2011) chokes on this allocate statement
   allocate(fileMetaData(numFiles))
#endif
   fileMetaData(:) % useCPP = .false.
   fileMetaData(:) % initialized = .false.
   i=0
   fi=1  ! file index
   do while (i.lt.argcount)
      i = i + 1
      call getarg(i, cmdlineopt)
      select case(trim(cmdlineopt))
         case("--datafile")
            i = i + 1
            call getarg(i, cmdlinearg)
            write(scratchMessage,'(a,a,a,a,a)') 'Processing "',trim(cmdlineopt),' ',trim(cmdlinearg),'".'
            call allMessage(INFO,scratchMessage)
            fileMetaData(fi)%dataFileName = trim(cmdlinearg)
            fileMetaData(fi)%dataFileFormat = NETCDFG
            fi = fi + 1
         case("--maureparticle")
            i = i + 1
            call getarg(i, cmdlinearg)
            write(scratchMessage,'(a,a,a,a,a)') 'Processing "',trim(cmdlineopt),' ',trim(cmdlinearg),'".'
            call allMessage(INFO,scratchMessage)
            fileMetaData(fi)%dataFileName = trim(cmdlinearg)
            fileMetaData(fi)%dataFileCategory = MAUREPT
            writeParticleFile = .true.
            fi = fi + 1
         case("--num-particles")  ! max number of particles in any dataset in the maureparticle file
            i = i + 1
            call getarg(i, cmdlinearg)
            write(scratchMessage,'(a,a,a,a,a)') 'Processing "',trim(cmdlineopt),' ',trim(cmdlinearg),'".'
            call allMessage(INFO,scratchMessage)
            read(cmdlinearg,*) numParticlesSpecified
         case("--num-particle-datasets")  ! max number of particles in any dataset in the maureparticle file
            i = i + 1
            call getarg(i, cmdlinearg)
            write(scratchMessage,'(a,a,a,a,a)') 'Processing "',trim(cmdlineopt),' ',trim(cmdlinearg),'".'
            call allMessage(INFO,scratchMessage)
            read(cmdlinearg,*) numParticleDatasetsSpecified
         case("--particle-start-time")  ! max number of particles in any dataset in the maureparticle file
            i = i + 1
            call getarg(i, cmdlinearg)
            write(scratchMessage,'(a,a,a,a,a)') 'Processing "',trim(cmdlineopt),' ',trim(cmdlinearg),'".'
            call allMessage(INFO,scratchMessage)
            read(cmdlinearg,*) particleStartTimeSec
         case("--particle-time-increment")  ! max number of particles in any dataset in the maureparticle file
            i = i + 1
            call getarg(i, cmdlinearg)
            write(scratchMessage,'(a,a,a,a,a)') 'Processing "',trim(cmdlineopt),' ',trim(cmdlinearg),'".'
            call allMessage(INFO,scratchMessage)
            read(cmdlinearg,*) particleDatasetTimeIncrement
         case("--xdmffile")
            i = i + 1
            call getarg(i, cmdlinearg)
            write(scratchMessage,'(a,a,a,a,a)') 'Processing "',trim(cmdlineopt),' ',trim(cmdlinearg),'".'
            call allMessage(INFO,scratchMessage)
            xdmfFile = trim(cmdlinearg)
         case("--logfile") ! already processed
            i = i + 1
         case("--loglevel") ! already processed
            i = i + 1
         case("--use-cpp")
            fileMetaData(:) % useCPP = .true.
            write(scratchMessage,'(a,a,a)') 'Processing ',trim(cmdlineopt),'.'
            call allMessage(INFO,scratchMessage)
         case("--getNodeIndices")
            getNodeIndices = .true.
            write(scratchMessage,'(a,a,a)') 'Processing ',trim(cmdlineopt),'.'
            call allMessage(INFO,scratchMessage)
         case("--getElementIndices")
            getElementIndices = .true.
            write(scratchMessage,'(a,a,a)') 'Processing ',trim(cmdlineopt),'.'
            call allMessage(INFO,scratchMessage)
         case default
            write(scratchMessage,'(a,a,a)') 'Command line option ',trim(cmdlineopt),' was not recognized.'
            call allMessage(WARNING,scratchMessage)
      end select
   end do
end if
if (numFiles.eq.0) then
   call allMessage(ERROR,'Please provide the name of a data file with the --datafile argument.')
   stop
endif
!
! Check to see if each file exists; if the file exists, initialize dimensions
do fi=1,numFiles
   call checkFileExistence(fileMetaData(fi)%dataFileName,errorIO)
   if (errorIO.gt.0) then
      stop
   endif
   if (fileMetaData(fi)%dataFileFormat.eq.NETCDFG) then
      call determineNetCDFFileCharacteristics(fileMetaData(fi), m, n)
       ! netcdf file exists; open it
      call check(nf90_open(trim(fileMetaData(fi)%dataFileName), NF90_NOWRITE, fileMetaData(fi)%nc_id))
      !
      ! Make sure the file is NetCDF4 formatted (i.e., HDF5 underneath) because
      ! this is required for XDMF.
      call check(nf90_inquire(fileMetaData(fi)%nc_id, formatNum=fileMetaData(fi)%ncformat))
      if ( (fileMetaData(fi)%ncformat.ne.nf90_format_netcdf4).and.(fileMetaData(fi)%ncformat.ne.nf90_format_netcdf4_classic) ) then
         call allMessage(ERROR,'The file '//trim(fileMetaData(fi)%dataFileName)//' is netcdf3 format; XDMF requires netcdf4 formatted files.')
         call check(nf90_close(fileMetaData(fi)%nc_id))
         stop
      else
         fileMetaData(fi)%dataFileFormat = NETCDF4
      endif
      !
      ! Inquire netCDF file about mesh dimensions, variables, and attributes.
      call check(nf90_inq_dimid(fileMetaData(fi)%nc_id, "node", n%NC_DimID_node))
      call check(nf90_inquire_dimension(fileMetaData(fi)%nc_id, n%NC_DimID_node, len=m%np))
      call check(nf90_inq_dimid(fileMetaData(fi)%nc_id, "nele", n%NC_DimID_nele))
      call check(nf90_inquire_dimension(fileMetaData(fi)%nc_id, n%NC_DimID_nele, len=m%ne))
      m%agrid = "mesh"
      call allMessage(INFO,'Read mesh dimensions from netCDF successfully.')
      ! Some netcdf files have the comment line at the top of the fort.14 in
      ! an attribute named "agrid" while in others the attribute is named "grid".
      ncStatus = nf90_get_att(fileMetaData(fi)%nc_id, NF90_GLOBAL, 'agrid', m%agrid)
      if ( ncStatus.ne.NF90_NOERR ) then
         ncStatus = nf90_get_att(fileMetaData(fi)%nc_id, NF90_GLOBAL, 'grid', m%agrid)
         if ( ncStatus.ne.NF90_NOERR ) then
            ! this can happen if a minimal hotstart file was written, e.g., by adcirpolate
            m%agrid = 'WARNING: Could not find the fort.14 comment line (grid or agrid attribute).'
         endif
      endif
      call check(nf90_close(fileMetaData(fi)%nc_id))
      if ( fileMetaData(fi)%dataFileCategory.eq.NODALATTRIBF ) then

      endif
   endif
   if (fileMetaData(fi)%dataFileCategory.eq.MAUREPT) then
      if ( (numParticlesSpecified.eq.0) .or. (numParticleDatasetsSpecified.eq.0) ) then
         maureIndex = fi  ! record which of the files is a maureparticle file
         call determineASCIIFileCharacteristics(fileMetaData(fi))
         ! open the file and determine the number of datasets as well as
         ! the number of particles in each dataset
         fileMetaData(fi)%fun = availableUnitNumber()
         call openFileForRead(fileMetaData(fi)%fun,fileMetaData(fi)%dataFileName,errorIO)
         fileMetaData(fi) % nSnaps = 1
         fileMetaData(fi) % maxParticles = 0
         allocate(numParticles(MAX_DATASETS)) ! allocate temporary space for num particles per dataset
         allocate(pTimesec(MAX_DATASETS)) ! allocate temporary space for particle dataset timestamps
         ! read first line of file
         lineNum = 1
         read(unit=fileMetaData(fi)%fun,fmt=*,end=123,err=456,iostat=errorIO) partID, lon, lat, timesec, ele
         pTimesec(1) = timesec
         oldtimesec = timesec
         particleCount = 1
         call allMessage(INFO,'Counting total number of datasets and peak number of particles in maureparticle file.')
         do ! loop until we run out of data
            ! read each line in the file; label 456 is at the end of this program and
            ! provides the line number that we attempted to read in error message prior to exiting
            lineNum = lineNum + 1
            read(unit=fileMetaData(fi)%fun,fmt=*,end=123,err=456,iostat=errorIO) partID, lon, lat, timesec, ele
            if (abs(timesec-oldtimesec).le.1.e-6) then
               ! same dataset
               particleCount = particleCount + 1
               fileMetaData(fi) % maxParticles = max(particleCount,fileMetaData(fi) % maxParticles)
            else
               ! reached a new dataset
               write(scratchMessage,'("There are ",i0," particles in dataset ",i0,".")') particleCount, fileMetaData(fi) % nSnaps
               call allMessage(DEBUG,scratchMessage)
               ! increment the number of datasets
               fileMetaData(fi) % nSnaps = fileMetaData(fi) % nSnaps + 1
               ! grab the timestamp
               pTimesec(fileMetaData(fi) % nSnaps) = timesec
               ! reset the counter
               particleCount = 1
            endif
            ! set the number of particles in this dataset
            numParticles(fileMetaData(fi) % nSnaps) = particleCount
            oldtimesec = timesec
         end do
         ! jump to 123 when running out of data
         123 call allMessage(INFO,'Finished counting number of datasets and peak number of particles in maureparticle file.')
         numLines = lineNum - 1
         write(scratchMessage,'("There are ",i0," datasets in the maureparticle file and the peak number of particles is ",i0,".")') fileMetaData(fi)%nSnaps, fileMetaData(fi) % maxParticles
         call allMessage(INFO,scratchMessage)
         ! allocate space for particle data
         allocate(particles(fileMetaData(fi)%maxParticles))
         allocate(fileMetaData(fi)%numParticlesPerSnap(fileMetaData(fi)%nSnaps))
         fileMetaData(fi) % numParticlesPerSnap(1:fileMetaData(fi)%nSnaps) = numParticles(1:fileMetaData(fi)%nSnaps)
         allocate(fileMetaData(fi)%timesec(fileMetaData(fi)%nSnaps))
         fileMetaData(fi) % timesec(1:fileMetaData(fi)%nSnaps) = pTimesec(1:fileMetaData(fi)%nSnaps)
         ! free up temp arrays
         deallocate(numParticles)
         deallocate(pTimesec)
         ! rewind back to the beginning for one more read to actually process the data
         rewind(fileMetaData(fi)%fun)
      else
         ! particle dataset parameters given on the command line
         maureIndex = fi  ! record which of the files is a maureparticle file
         call determineASCIIFileCharacteristics(fileMetaData(fi))
         ! open the file and set the number of datasets as well as
         ! the number of particles in each dataset (from command line arguments)
         fileMetaData(fi)%fun = availableUnitNumber()
         call openFileForRead(fileMetaData(fi)%fun,fileMetaData(fi)%dataFileName,errorIO)
         fileMetaData(fi) % nSnaps = numParticleDatasetsSpecified
         fileMetaData(fi) % maxParticles = numParticlesSpecified
         write(scratchMessage,'("There are ",i0," datasets in the maureparticle file and the peak number of particles is ",i0,".")') fileMetaData(fi)%nSnaps, fileMetaData(fi) % maxParticles
         call allMessage(INFO,scratchMessage)
         ! allocate space for particle data
         allocate(particles(fileMetaData(fi)%maxParticles))
         allocate(fileMetaData(fi)%numParticlesPerSnap(fileMetaData(fi)%nSnaps))
         fileMetaData(fi) % numParticlesPerSnap(1:fileMetaData(fi)%nSnaps) = numParticlesSpecified
         allocate(fileMetaData(fi)%timesec(fileMetaData(fi)%nSnaps))
         ! populate the array of times associated with each particle dataset
         particleTimeSec = particleStartTimeSec
         do ds=1,numParticleDatasetsSpecified
            fileMetaData(fi) % timesec(1:fileMetaData(fi)%nSnaps) = particleTImeSec
            particleTimeSec = particleTimeSec + particleDatasetTimeIncrement
         end do
      endif
   endif
 246  fileMetaData(fi) % initialized = .true.
end do
!
! Form the file name of XDMF xml file and open it.
call allMessage(INFO,'Writing XDMF xml header.')
if (trim(xdmfFile).eq.'null') then
   xdmfFile = trim(fileMetaData(1)%dataFileName)
   do fi=2,numFiles
      xdmfFile = trim(xdmfFile) // '_' // trim(fileMetaData(fi)%dataFileName)
   end do
   xdmfFile = trim(xdmfFile)//".xmf"
   if (writeParticleFile.eqv..true.) then
      xdmfFile = 'particles.xmf'
   endif
endif
olun = availableUnitNumber()
open(olun,file=xdmfFile,status='replace')
! write the beginning of the XDMF xml file
write(olun,'(a)') '<?xml version="1.0" encoding="utf-8"?>'
!write(olun,'(a)') '<!DOCTYPE Xdmf SYSTEM "Xdmf.dtd" []>' ! not needed?
!write(olun,'(a)') '<Xdmf Version="2.0">'                 ! deprecated
write(olun,'(a)') '<Xdmf xmlns:xi="http://www.w3.org/2001/XInclude" Version="2.1">'
!
if (writeParticleFile.eqv..true.) then
   write(olun,'('//ind('+')//',a)') '<Domain Name="maureparticle">'
else
   write(olun,'('//ind('+')//',a)') '<Domain Name="'//adjustl(trim(m%agrid))//'">'
endif
!
! Bomb out if we did not recognize any of the variable names in the file
! or if only the mesh should be written.
do fi=1,numFiles
   if ( (meshonly.eqv..true.).or.(fileMetaData(fi) % dataFileCategory.eq.MESH) ) then
      call allMessage(INFO,'The '//trim(xdmfFile)//' xml file will only contain mesh-related information.')
      write(olun,'('//ind('+')//',a)') '<Grid Name="'//adjustl(trim(m%agrid))//'" GridType="Uniform">'
      ! Write mesh portion of XDMF xml file.
      call writeMeshTopologyGeometryDepth(fileMetaData(fi), m, olun, .true.)
      ! finish off the xml so the user can at least look at the mesh
      write(olun,'('//ind('-')//',a)') '</Grid>'
      call writeFooterXML(olun)
      close(olun)
      call allMessage(INFO,'Terminating after writing mesh-related into to xml file.')
      stop
   else
      ! log the guessed type of the file(s) for the user
      call allMessage(INFO,'Preparing to write XDMF xml for '//trim(fileMetaData(fi)%fileTypeDesc)//'.')
   endif
end do
!
! If the file list only contains data that are not time varying,
! (e.g., hotstart files, min/max files, and nodal attributes files),
! then write XDMF Attributes to the same Grid as the mesh itself and
! be done with it
do fi=1,numFiles
   allTimeInvariant = .true.
   if ( fileMetaData(fi)%timeVarying.eqv..true. ) then
      call allMessage(INFO,'The list of files contains at least one time varying data file.')
      allTimeInvariant = .false.
      exit
   endif
end do
if ( allTimeInvariant.eqv..true. ) then
   write(olun,'('//ind('+')//',A)') '<Grid GridType="Uniform">'
   call writeMeshTopologyGeometryDepth(fileMetaData(1), m, olun, meshonly)
   do fi=1,numFiles
      call initNamesXDMF(fileMetaData(fi))
      call writeAttributesXML(fileMetaData(fi), m, 1, 1, olun)
   end do
   write(olun,'('//ind('|')//',A)') '</Grid>'
   call writeFooterXML(olun)
   close(olun)
   do fi=1,numFiles
      call allMessage(INFO,'Finished writing XDMF xml for '//trim(fileMetaData(fi)%fileTypeDesc)//'.')
   end do
   stop
endif
!
! Load up the node and element tables if we are writing a maureparticle file
! so that we can interpolate the physical quantities to the particle
! location. This will allow us to color the particles according to any
! scalar in the xmf file, as well as warp the particle locations up
! or down with the water surface elevation.
if ((writeParticleFile.eqv..true.).and.(meshInitialized.eqv..false.)) then
   do fi=1,numFiles
      if (fileMetaData(fi)%dataFileFormat.eq.NETCDF4) then
         call check(nf90_open(trim(fileMetaData(fi)%dataFileName), NF90_NOWRITE, fileMetaData(fi)%nc_id))
         m%meshFileName = trim(fileMetaData(fi)%dataFileName)
         !!call findMeshDimsNetCDF(fileMetaData(fi)%dataFileName, n)
         call readMeshNetCDF(m, n)
         call check(nf90_close(fileMetaData(fi)%nc_id))
         meshInitialized = .true.
         exit
      endif
   end do
endif
!
! checks
nSnaps = -99
do fi=1,numFiles
   !
   ! Check to make sure that all the files have the same number of datasets
   if ( fileMetaData(fi)%timeVarying .eqv..true. ) then
      !
      ! Write meta data for time varying data snapshots to XML.
      write(scratchMessage,'(a,i0,a,a,a)') 'There are ',fileMetaData(fi)%nSnaps, &
      ' time values (snapshots) in the file ',trim(fileMetaData(fi)%dataFileName),'.'
      call allMessage(INFO,scratchMessage)
      if ( (nSnaps.ne.-99).and.(fileMetaData(fi)%nSnaps.ne.nSnaps) ) then
        call allMessage(ERROR,'The time varying files do not all have the same number of datasets.')
        stop
      endif
      nSnaps = fileMetaData(fi)%nSnaps
   endif
   !
   ! Check to make sure all the datasets have the same time stamp
   !do iSnap=1,fileMetaData(fi)%nSnaps
   !   if ( fileMetaData(fi)%timesec(iSnap).ne.fileMetaData(fi-1)%timesec(iSnap) ) then
   !      call allMessage(ERROR,'Corresponding datasets from different files have different time stamps.')
   !      stop
   !   endif
   !end do
end do
!
! Write the metadata for each snapshot in time.
write(olun,'('//ind('+')//',A)') '<Grid Name="TimeSeries" GridType="Collection" CollectionType="Temporal">'
!
! This assumes all files have the same number of datasets and that
! the datasets correspond to the same times
if (writeParticleFile.eqv..true.) then
   do iSnap=1,fileMetaData(maureIndex)%nSnaps
      call readTimeVaryingParticlePositions(fileMetaData(maureIndex),particles,fileMetaData(maureIndex)%maxParticles,iSnap)
      call writeTimeVaryingGrid(fileMetaData(maureIndex), iSnap, olun) ! just the header
      call writeTimeVaryingParticlePositions(fileMetaData(maureIndex),particles,fileMetaData(maureIndex)%maxParticles,iSnap,olun)
      ! if there are files other than a particle file, then load these
      ! as well and interpolate all the quantities found there
      if (numFiles.gt.1) then
         do fi=1,numFiles
            if (fi.eq.maureIndex) then
               cycle
            endif
            call interpolateAndWriteTimeVaryingAttributesXML(fileMetaData(fi), fileMetaData(maureIndex), m, particles, fileMetaData(maureIndex)%maxParticles, iSnap, olun)
         end do
         ! TODO:load bathy depth to interpolate that too
         !call interpolateAndWriteTimeVaryingAttributesXML(fileMetaData(fi), fileMetaData(maureIndex), m, particles, fileMetaData(maureIndex)%maxParticles, iSnap, olun)
      endif
      write(olun,'('//ind('-')//',A)') '</Grid>' ! closing element for time varying grid
   end do
else
   ! writing XDMF xml for ADCIRC meshed data
   do iSnap=1,nSnaps
      call writeTimeVaryingGrid(fileMetaData(1), iSnap, olun)
      if (iSnap.eq.1) then
         call writeMeshTopologyGeometryDepth(fileMetaData(1), m, olun, meshonly)
         do fi=1,numFiles
            if (fileMetaData(fi)%timeVarying.eqv..false.) then
               call writeAttributesXML(fileMetaData(fi), m, 1, 1, olun)
            endif
         end do
      else
         call writeMeshTopologyGeometryDepthByReference(fileMetaData(1), olun, meshonly)
         do fi=1,numFiles
            if (fileMetaData(fi)%timeVarying.eqv..false.) then
               call writeAttributesXMLByReference(fileMetaData(fi), olun)
            endif
         end do
      endif
      do fi=1,numFiles
         if (fileMetaData(fi)%timeVarying.eqv..true.) then
            call writeTimeVaryingAttributesXML(fileMetaData(fi), m, iSnap, fileMetaData(1)%nSnaps, olun)
         endif
      end do
      write(olun,'('//ind('-')//',A)') '</Grid>' ! closing element for time varying grid
   end do
end if
write(6,*) 'nSnaps=',nSnaps
write(olun,'('//ind('-')//',A)') '</Grid>' ! closing element for temporal grid collection
call writeFooterXML(olun)
close(olun)
!
call allMessage(INFO,'Finished generating XDMF xml.')

stop

! jump to here when encountering i/o error when reading Maureparticle file
456 write(scratchMessage,'("Attempted to read line ",i0," from the maureparticle file ",a," when an i/o error occurred. The Fortran error code was ",i0,".")') lineNum, trim(fileMetaData(fi)%dataFileName), errorIO
call allMessage(ERROR,scratchMessage)
stop
!----------------------------------------------------------------------
end program generateXDMF
!----------------------------------------------------------------------


!----------------------------------------------------------------------
!  S U B R O U T I N E     I N I T   N A M E S   X D M F
!----------------------------------------------------------------------
! Initialize the names of the variables in the XMDF files to reasonable
! names (that will be renamed, at least in the case of vector data,
! in the calling routine).
! Added the initialization of the data type.
!----------------------------------------------------------------------
subroutine initNamesXDMF(fmd)
use netcdf
use asgsio, only : fileMetaData_t
use logging, only : allMessage, ERROR
use ioutil, only : check, HOTSTART
implicit none
type(fileMetaData_t) :: fmd
integer :: i, j
!
! netcdf file exists; open it
call check(nf90_open(trim(fmd%dataFileName), NF90_NOWRITE, fmd%nc_id))
! find the netcdf variable IDs
do i=1,fmd % numVarNetCDF
   call check(nf90_inq_varid(fmd%nc_id, fmd%ncds(i)%varNameNetCDF, fmd%ncds(i)%nc_varID))
   call check(nf90_inquire_variable(fmd%nc_id, fmd%ncds(i)%nc_varID, fmd%ncds(i)%varNameNetCDF, fmd%ncds(i)%nc_varType))
end do
! set the names of the XDMF data
i=1 ! netcdf variable counter
j=1 ! xdmf variable counter
do
   ! for vector data, the name will be replaced in the calling routine anyway
   if (trim(fmd%ncds(i)%varNameNetCDF).ne."noff") then
      !write(6,'(a,a)') 'DEBUG: generateXDMF: seeking NetCDF variable ID for ',trim(fmd%varNameNetCDF(i))
      ! the standard_name attribute is missing for noff in some netcdf hotstart files
      call check(nf90_get_att(fmd%nc_id, fmd%ncds(i)%nc_varID, 'standard_name', fmd%xds(j)%varNameXDMF))
   endif
   !
   ! Apply a fix for old versions of ADCIRC that misnamed nodecode and
   ! noff in the netcdf hotstart files (nodecode was given the standard_name
   ! of "element_wet_or_dry" while noff was given no standard name at all).
   if (trim(fmd%ncds(i)%varNameNetCDF).eq."nodecode") then
      fmd%xds(j)%varNameXDMF = "node_wet_or_dry"
   endif
   if (trim(fmd%ncds(i)%varNameNetCDF).eq."noff") then
      fmd%xds(j)%varNameXDMF = "element_wet_or_dry"
   endif
   select case(fmd%ncds(i)%nc_varType)
   case(NF90_INT)
      fmd%xds(j)%numberType = "Int"
      fmd%xds(j)%numberPrecision = 4
   case(NF90_FLOAT)
      fmd%xds(j)%numberType = "Float"
      fmd%xds(j)%numberPrecision = 4
   case(NF90_DOUBLE)
      fmd%xds(j)%numberType = "Float"
      fmd%xds(j)%numberPrecision = 8
   case default
      call allMessage(ERROR,'The netCDF variable '//trim(fmd%ncds(i)%varNameNetCDF)//' uses an unknown data type.')
      stop
   end select
   if ( fmd % ncds(i)%isElemental .eqv. .true. ) then   ! noff<---element/cell centered
      fmd%xds(j)%dataCenter="Cell"
   endif
   write(6,'(a,i0,a)') 'DEBUG: generateXDMF: varNameNetCDF(',i,')='//trim(fmd%ncds(i)%varNameNetCDF)
   write(6,'(a,i0,a)') 'DEBUG: generateXDMF: varNameXDMF(',j,')='//trim(fmd%xds(j)%varNameXDMF)
   write(6,'(a,i0,a,i0)') 'DEBUG: generateXDMF: nc_varType(',i,')=',fmd%ncds(i)%nc_varType
   if ( fmd%dataFileCategory.eq.HOTSTART ) then ! hotstart files don't have irtype
      i = i + fmd % xds(j) % numComponents
   else
      i = i + fmd % irtype ! multi component (vector) data only need 1 name
   endif
   j = j + 1
   if (j.gt.fmd % numVarXDMF) exit
end do
! close netcdf file
call check(nf90_close(fmd%nc_id))
!----------------------------------------------------------------------
end subroutine initNamesXDMF
!----------------------------------------------------------------------

!----------------------------------------------------------------------
!                   S U B R O U T I N E
! W R I T E   M E S H   T O P O L O G Y   G E O M E T R Y   D E P T H
!----------------------------------------------------------------------
! Writes the mesh portion of the XML.
!----------------------------------------------------------------------
subroutine writeMeshTopologyGeometryDepth(fmd, m, olun, meshonly)
use asgsio, only : fileMetaData_t
use ioutil, only : ind
use adcmesh
implicit none
type(fileMetaData_t), intent(in) :: fmd
type(mesh_t), intent(in) :: m
integer, intent(in) :: olun ! i/o unit number to write XDMF xml to
logical, intent(in) :: meshonly ! true if only the mesh xml are being written
character(len=1) :: indent
!
indent = '|'
if (meshonly.eqv..true.) then
   indent = '+'
endif
write(olun,'('//ind(indent)//',a)') '<Topology Name="ADCIRCMesh"'
write(olun,'('//ind('|')//',A)')     '  TopologyType="Triangle"'
write(olun,'('//ind('|')//',A)')     '  NodesPerElement="3"'
write(olun,'('//ind('|')//',A,i0,A)')'  NumberOfElements="',m%ne,'"'
write(olun,'('//ind('|')//',A)')     '  BaseOffset="1">'
write(olun,'('//ind('+')//',A,i0,A)') '<DataItem Dimensions="',m%ne,'  3"'
write(olun,'('//ind('|')//',A)')       '  DataType="Int"'
write(olun,'('//ind('|')//',A)')       '  Format="HDF">'//trim(fmd%dataFileName)//':/element'
write(olun,'('//ind('|')//',A)')      '</DataItem>'
write(olun,'('//ind('-')//',A)') '</Topology>'
write(olun,'('//ind('|')//',A)') '<Geometry Name="NodeLocations"'
write(olun,'('//ind('|')//',A)') '  GeometryType="X_Y">'
write(olun,'('//ind('+')//',A,i0,A)') '<DataItem Dimensions="',m%np,'"'
write(olun,'('//ind('|')//',A)')      '   NumberType="Float"'
write(olun,'('//ind('|')//',A)')      '   Precision="8"'
if (fmd%useCPP.eqv..true.) then
   write(olun,'('//ind('|')//',A)')   '   Format="HDF">'//trim(fmd%dataFileName)//':/x_cpp'
else
   write(olun,'('//ind('|')//',A)')   '   Format="HDF">'//trim(fmd%dataFileName)//':/x'
endif
write(olun,'('//ind('|')//',A)')      '</DataItem>'
write(olun,'('//ind('|')//',A,i0,A)') '<DataItem Dimensions="',m%np,'"'
write(olun,'('//ind('|')//',A)')      '  NumberType="Float"'
write(olun,'('//ind('|')//',A)')      '  Precision="8"'
if (fmd%useCPP.eqv..true.) then
   write(olun,'('//ind('|')//',A)')   '  Format="HDF">'//trim(fmd%dataFileName)//':/y_cpp'
else
   write(olun,'('//ind('|')//',A)')   '  Format="HDF">'//trim(fmd%dataFileName)//':/y'
endif
write(olun,'('//ind('|')//',A)')      '</DataItem>'
write(olun,'('//ind('-')//',A)')   '</Geometry>'
write(olun,'('//ind('|')//',A)')   '<Attribute Name="BathymetricDepth"'
write(olun,'('//ind('|')//',A)')   '  AttributeType="Scalar"'
write(olun,'('//ind('|')//',A)')   '  Center="Node">'
write(olun,'('//ind('+')//',A,i0,A)') '<DataItem Dimensions="',m%np,'"'
write(olun,'('//ind('|')//',A)')      '  NumberType="Float"'
write(olun,'('//ind('|')//',A)')      '  Precision="8"'
write(olun,'('//ind('|')//',A)')      '  Format="HDF">'//trim(fmd%dataFileName)//':/depth'
write(olun,'('//ind('|')//',A)')      '</DataItem>'
write(olun,'('//ind('-')//',A)')   '</Attribute>'
!----------------------------------------------------------------------
end subroutine writeMeshTopologyGeometryDepth
!----------------------------------------------------------------------


!----------------------------------------------------------------------
!                   S U B R O U T I N E
! W R I T E   M E S H   T O P O L O G Y   G E O M E T R Y   D E P T H
!                 B Y   R E F E R E N C E
!----------------------------------------------------------------------
! Writes the mesh portion of the XML in time varying output files where
! the mesh is unchanging by referring to the Geometry, Topology, and
! Depth Attribute elements that defined previously using xinclude.
!----------------------------------------------------------------------
subroutine writeMeshTopologyGeometryDepthByReference(fmd, olun, meshonly)
use asgsio, only : fileMetaData_t
use ioutil, only : ind
use adcmesh
implicit none
type(fileMetaData_t), intent(in) :: fmd
integer, intent(in) :: olun ! i/o unit number to write XDMF xml to
logical, intent(in) :: meshonly ! true if only the mesh xml are being written
character(len=1) :: indent
!
indent = '|'
if (meshonly.eqv..true.) then
   indent = '+'
endif
! Topology
write(olun,'('//ind(indent)//',a)') '<xi:include xpointer="element(/1/1/1/1/2)"/>'
! Geometry
write(olun,'('//ind('|')//',a)') '<xi:include xpointer="element(/1/1/1/1/3)"/>'
! Depth Attribute
write(olun,'('//ind('|')//',a)') '<xi:include xpointer="element(/1/1/1/1/4)"/>'

!----------------------------------------------------------------------
end subroutine writeMeshTopologyGeometryDepthByReference
!----------------------------------------------------------------------


!----------------------------------------------------------------------
!  S U B R O U T I NE   W R I T E   T I M E   V A R Y I N G   G R I D
!----------------------------------------------------------------------
! Creates the Grid metadata inside the Temporal collection to describe
! each time snap.
!----------------------------------------------------------------------
subroutine writeTimeVaryingGrid(fmd, isnap, olun)
use asgsio, only : fileMetaData_t
use ioutil, only : ind
implicit none
type(fileMetaData_t), intent(in) :: fmd
integer, intent(in) :: isnap ! the dataset number from the file
integer, intent(in) :: olun ! i/o unit number to write XDMF xml to
character(len=1) :: indent
!
indent = '|'
if (isnap.eq.1) then
   indent = '+'
endif
! Write the Grid xml for the time varying data
! now write XDMF XML data for this dataset
write(olun,'('//ind(indent)//',A,E22.15,A)') '<Grid Name="Time=',fmd%timesec(isnap),'" GridType="Uniform">'
write(olun,'('//ind('+')//',A,E22.15,A)') '<Time Value="',fmd%timesec(isnap),'"/>'

!----------------------------------------------------------------------
end subroutine writeTimeVaryingGrid
!----------------------------------------------------------------------

!----------------------------------------------------------------------
!  S U B R O U T I N E    W R I T E   A T T R I B U T E S   X M L
!----------------------------------------------------------------------
! Writes the Attribute(s) metadata to an XML file.
!----------------------------------------------------------------------
subroutine writeAttributesXML(fmd, m, iSnap, nSnaps, olun)
use adcmesh
use asgsio, only : fileMetaData_t
use ioutil, only : ind
use logging
implicit none
type(fileMetaData_t), intent(inout) :: fmd
type(mesh_t), intent(inout) :: m
integer, intent(in) :: iSnap
integer, intent(in) :: nSnaps
integer, intent(in) :: olun ! i/o unit number to write XDMF xml to
!
integer :: dataItemDimensions
character(len=20) :: attributeType
integer :: i, j, k, p, xmlRef
!
i=1 ! netCDF variable counter
j=1 ! XDMF variable counter
xmlRef=5 ! xml reference counter; topology=2, geometry=3, depth=4
p = 0 ! hyperslab component counter
do
   dataItemDimensions = m%np
   if (trim(fmd%xds(j)%dataCenter).eq."Cell") then
      dataItemDimensions = m%ne
   endif
   select case(fmd%xds(j)%numComponents)
   case(:0) ! multicomponent nodal attribute
      attributeType = "HyperSlab"
   case(2:)
      attributeType = "Vector"
   case default
      attributeType = "Scalar"
   end select
   fmd%xds(j)%xmlReference = xmlRef
   xmlRef = xmlRef + 1
   !
   write(olun,'('//ind('|')//',A)') '<Attribute Name="'//trim(fmd%xds(j)%varNameXDMF)//'"'
   write(olun,'('//ind('|')//',A)') '  Center="'//trim(fmd%xds(j)%dataCenter)//'"'

   select case(trim(attributeType))
   !
   ! Scalar attribute
   case("Scalar")
      write(olun,'('//ind('|')//',A)') '  AttributeType="'//trim(attributeType)//'">'
      write(olun,'('//ind('+')//',A,i0,A)') '<DataItem Dimensions="',dataItemDimensions,'"'
      write(olun,'('//ind('|')//',a,a,a)')  '  NumberType="',trim(fmd%xds(j)%numberType),'"'
      write(olun,'('//ind('|')//',a,i0,a)') '  Precision="',fmd%xds(j)%numberPrecision,'"'
      write(olun,'('//ind('|')//',A)')      '  Format="HDF">'//trim(fmd%dataFileName)//':/'//trim(fmd%ncds(i)%varNameNetCDF)
      write(olun,'('//ind('|')//',A)')      '</DataItem>'
      write(olun,'('//ind('-')//',A)')   '</Attribute>' ! end of scalar attribute
      i = i + 1
   !
   ! Vector attribute
   case("Vector")
      write(olun,'('//ind('|')//',A)') '  AttributeType="'//trim(attributeType)//'">'
      write(olun,'('//ind('|')//',A)')      '<DataItem ItemType="Function"'
      write(olun,'('//ind('|')//',A,i0,A)') '  Dimensions="',dataItemDimensions,' 3"'
      write(olun,'('//ind('|')//',A)')      '  Function="JOIN($0, $1, 0*$0)">'
      do k=0,fmd%xds(j)%numComponents-1
         if (k.eq.0) then
            write(olun,'('//ind('+')//',A)')   '<DataItem ItemType="HyperSlab"'
         else
            write(olun,'('//ind('|')//',A)')   '<DataItem ItemType="HyperSlab"'
         endif
         write(olun,'('//ind('|')//',A,i0,A)') '  Dimensions="',dataItemDimensions,'"'
         write(olun,'('//ind('|')//',A)')      '  Type="HyperSlab">'
         write(olun,'('//ind('+')//',A)')         '<DataItem Dimensions="3 2"'
         write(olun,'('//ind('|')//',A)')         '  Format="XML">'
         write(olun,'('//ind('|')//',A,i0,A)')    '  ',iSnap-1,' 0'
         write(olun,'('//ind('|')//',A)')         '  1 1'
         write(olun,'('//ind('|')//',A,i0)')      '  1 ',dataItemDimensions
         write(olun,'('//ind('|')//',A)')         '</DataItem>' ! end of dimensions
         ! a steady vector attribute still has to have a first
         ! dimension of 1 instead of nSnaps-1
         write(olun,'('//ind('|')//',A,i0,A)')    '<DataItem Dimensions="1 ',dataItemDimensions,'"'
         write(olun,'('//ind('|')//',a,a,a)')     '  NumberType="',trim(fmd%xds(j)%numberType),'"'
         write(olun,'('//ind('|')//',a,i0,a)')    '  Precision="',fmd%xds(j)%numberPrecision,'" Format="HDF">'//trim(fmd%dataFileName)//':/'//trim(fmd%ncds(i+k)%varNameNetCDF)
         write(olun,'('//ind('|')//',A)')         '</DataItem>' ! end of Dimensions
         write(olun,'('//ind('-')//',A)')      '</DataItem>' ! end of HyperSlab
      enddo
      write(olun,'('//ind('-')//',A)')      '</DataItem>' ! end of FUNCTION
      write(olun,'('//ind('-')//',A)')   '</Attribute>' ! end of Vector Attribute
      i = i + fmd%xds(j)%numComponents
   !
   ! multicomponent nodal attribute
   case("HyperSlab")
      write(olun,'('//ind('|')//',a,a,a)')  '  NumberType="',trim(fmd%xds(j)%numberType),'"'
      write(olun,'('//ind('|')//',a,i0,a)') '  Precision="',fmd%xds(j)%numberPrecision,'"'
      write(olun,'('//ind('|')//',A)') '  AttributeType="Scalar">'
      write(olun,'('//ind('+')//',A)')   '<DataItem ItemType="HyperSlab"'
      write(olun,'('//ind('|')//',A,i0,A)') '  Dimensions="1 ',dataItemDimensions,'"'
      write(olun,'('//ind('|')//',A,i0,A)') '  Type="HyperSlab">'
      write(olun,'('//ind('+')//',A)')         '<DataItem Dimensions="3 2"'
      write(olun,'('//ind('|')//',A)')         '  Format="XML">'
      write(olun,'('//ind('|')//'a,i0,a)')     '  ',abs(p),' 0'
      write(olun,'('//ind('|')//',A)')         '  1 1'
      write(olun,'('//ind('|')//',A,i0)')      '  1 ',dataItemDimensions
      write(olun,'('//ind('-')//',A)')      '</DataItem>' ! end of HyperSlab dimensions
      write(olun,'('//ind('+')//',A,i0,X,i0,A)') '<DataItem Dimensions="',abs(fmd%xds(j)%numComponents),dataItemDimensions,'"'
      write(olun,'('//ind('|')//',a,a,a)') '   Name="',trim(fmd%ncds(i)%varNameNetCDF),'"'

      write(olun,'('//ind('|')//',A)')      '  Format="HDF">'//trim(fmd%dataFileName)//':/'//trim(fmd%ncds(i)%varNameNetCDF)
      write(olun,'('//ind('|')//',A)')      '</DataItem>' ! end of overall dimensions
      write(olun,'('//ind('-')//',A)')      '</DataItem>' ! end of HyperSlab
      write(olun,'('//ind('-')//',A)')   '</Attribute>' ! end of Vector Attribute
      p = p - 1
      ! check to see if this is the last section of the hyperslab
      if ( p.eq.fmd%xds(j)%numComponents ) then
         i = i + 1 ! increment the netcdf variable we are pointing to
         p = 0     ! reset the hyperslab component counter
      endif
   case default
      call allMessage(WARNING,'XDMF Attribute type '//trim(attributeType)//' was not recognized.')
   end select
   j = j + 1
   if (j.gt.fmd%numVarXDMF) then
      exit
   endif
end do
!----------------------------------------------------------------------
end subroutine writeAttributesXML
!----------------------------------------------------------------------

!----------------------------------------------------------------------
!                     S U B R O U T I N E
!           W R I T E   A T T R I B U T E S   X M L
!                  B Y   R E F E R E N C E
!----------------------------------------------------------------------
! Writes the Attribute(s) metadata to an XML file for time invariant
! data to a time varying XDMF file using references.
!----------------------------------------------------------------------
subroutine writeAttributesXMLByReference(fmd, olun)
use adcmesh
use asgsio, only : fileMetaData_t
use ioutil, only : ind
use logging
implicit none
type(fileMetaData_t), intent(in) :: fmd
integer, intent(in) :: olun ! i/o unit number to write XDMF xml to
!
integer :: i
!
do i=1,fmd%numVarXDMF
   write(olun,'('//ind('|')//',a,i0,a)') &
   '<xi:include xpointer="element(/1/1/1/1/',fmd%xds(i)%xmlReference,')"/>'
end do
!----------------------------------------------------------------------
end subroutine writeAttributesXMLByReference
!----------------------------------------------------------------------

!----------------------------------------------------------------------
!                     S U B R O U T I N E
!   W R I T E   T I M E   V A R Y I N G  A T T R I B U T E S   X M L
!----------------------------------------------------------------------
! Writes the Attribute(s) metadata to an XML file for a particular
! snapshot in time. This requires the use of a hyperslab for both
! Scalar and Vector Attributes, because the ADCIRC time series data
! in a NetCDF file are held in one large m x t matrix (where t is the
! time dimension).
!----------------------------------------------------------------------
subroutine writeTimeVaryingAttributesXML(fmd, m, iSnap, nSnaps, olun)
use adcmesh
use asgsio, only : fileMetaData_t
use ioutil, only : ind
implicit none
type(fileMetaData_t), intent(in) :: fmd
type(mesh_t), intent(in) :: m
integer, intent(in) :: iSnap
integer, intent(in) :: nSnaps
integer, intent(in) :: olun ! i/o unit number to write XDMF xml to
!
integer :: domainExtent
character(len=20) :: attributeType
integer :: i, j, k
!
attributeType = "Scalar"
domainExtent = m%np
!
i=1 ! netCDF variable counter
j=1 ! XDMF variable counter
do
   if (fmd%xds(j)%numComponents.gt.1) then
      attributeType = "Vector"
   endif
   if (trim(fmd%xds(j)%dataCenter).eq."Cell") then
      domainExtent = m%ne
   endif
   !@jasonflemingdebug
   !write(6,*) trim(fmd%xds(j)%varNameXDMF), fmd%xds(j)%numComponents, trim(attributeType)
   !
   write(olun,'('//ind('|')//',A)') '<Attribute Name="'//trim(fmd%xds(j)%varNameXDMF)//'"'
   write(olun,'('//ind('|')//',A)') '  Center="'//trim(fmd%xds(j)%dataCenter)//'"'
   write(olun,'('//ind('|')//',A)') '  AttributeType="'//trim(attributeType)//'">'
   !
   ! Scalar attribute
   if (trim(attributeType).eq."Scalar") then
      write(olun,'('//ind('+')//',A)')    '<DataItem ItemType="HyperSlab"'
      write(olun,'('//ind('|')//',A,i0,A)')'  Dimensions="',domainExtent,'"'
      write(olun,'('//ind('|')//',A)')    '   Type="HyperSlab">'

      write(olun,'('//ind('+')//',A)')    '<DataItem Dimensions="3  2"'
      write(olun,'('//ind('|')//',A)')    '  Format="XML">'
      write(olun,'('//ind('|')//',A,i0,A)')'  ',iSnap-1,' 0'
      write(olun,'('//ind('|')//',A)')    '  1 1'
      write(olun,'('//ind('|')//',A,i0)') '  1 ',domainExtent
      write(olun,'('//ind('|')//',A)')    '</DataItem>'

      write(olun,'('//ind('|')//',A,i0,1x,i0,A)') '<DataItem Dimensions="',nSnaps-1,domainExtent,'"'
      write(olun,'('//ind('|')//',a,a,a)')        '  NumberType="',trim(fmd%xds(j)%numberType),'"'
      write(olun,'('//ind('|')//',a,i0,a)')       '  Precision="',fmd%xds(j)%numberPrecision,'"'
      write(olun,'('//ind('|')//',A)')            '  Format="HDF">'//trim(fmd%dataFileName)//':/'//trim(fmd%ncds(i)%varNameNetCDF)
      write(olun,'('//ind('|')//',A)')            '</DataItem>'
      write(olun,'('//ind('-')//',A)')         '</DataItem>'
      write(olun,'('//ind('-')//',A)')      '</Attribute>' ! end of scalar attribute
   !
   ! Vector attribute
   else
      write(olun,'('//ind('+')//',A)')      '<DataItem ItemType="Function"'
      write(olun,'('//ind('|')//',A,i0,A)') '  Dimensions="',domainExtent,' 3"'
      write(olun,'('//ind('|')//',A)')      '  Function="JOIN($0, $1, 0*$0)">'
      do k=0,fmd%xds(j)%numComponents-1
         if (k.eq.0) then
            write(olun,'('//ind('+')//',A)')   '<DataItem ItemType="HyperSlab"'
         else
            write(olun,'('//ind('|')//',A)')   '<DataItem ItemType="HyperSlab"'
         endif
         write(olun,'('//ind('|')//',A,i0,A)') '  Dimensions="',domainExtent,'"'
         write(olun,'('//ind('|')//',A)')      '  Type="HyperSlab">'
         write(olun,'('//ind('+')//',A)')         '<DataItem Dimensions="3 2"'
         write(olun,'('//ind('|')//',A)')         '  Format="XML">'
         write(olun,'('//ind('|')//',A,i0,A)')    '  ',iSnap-1,' 0'
         write(olun,'('//ind('|')//',A)')         '  1 1'
         write(olun,'('//ind('|')//',A,i0)')      '  1 ',domainExtent
         write(olun,'('//ind('|')//',A)')         '</DataItem>' ! end of dimensions
         write(olun,'('//ind('|')//',A,i0,1x,i0,A)') '<DataItem Dimensions="',nSnaps-1,domainExtent,'"'
         write(olun,'('//ind('|')//',a,a,a)')        '  NumberType="',trim(fmd%xds(j)%numberType),'"'
         write(olun,'('//ind('|')//',a,i0,a)')       '  Precision="',fmd%xds(j)%numberPrecision,'"'
         write(olun,'('//ind('|')//',A)')            '  Format="HDF">'//trim(fmd%dataFileName)//':/'//trim(fmd%ncds(i+k)%varNameNetCDF)
         write(olun,'('//ind('|')//',A)')            '</DataItem>' ! end of Dimensions
         write(olun,'('//ind('-')//',A)')         '</DataItem>' ! end of HyperSlab
      enddo
      write(olun,'('//ind('-')//',A)')         '</DataItem>' ! end of FUNCTION
      write(olun,'('//ind('-')//',A)')      '</Attribute>' ! end of Vector Attribute
   endif
   i = i + fmd%xds(j)%numComponents
   j = j + 1
   if (j.gt.fmd%numVarXDMF) then
      exit
   endif
end do
!----------------------------------------------------------------------
end subroutine writeTimeVaryingAttributesXML
!----------------------------------------------------------------------



!----------------------------------------------------------------------
!  S U B R O U T I N E     W R I T E   F O O T E R   X M L
!----------------------------------------------------------------------
subroutine writeFooterXML(olun)
use ioutil, only : ind
implicit none
integer, intent(in) :: olun

write(olun,'('//ind('-')//',a)') '</Domain>'
write(olun,'(a)') '</Xdmf>'

!----------------------------------------------------------------------
end subroutine writeFooterXML
!----------------------------------------------------------------------


!----------------------------------------------------------------------
!                     S U B R O U T I N E
!              R E A D   T I M E   V A R Y I N G
!             P A R T I C L E   P O S I T I O N S
!----------------------------------------------------------------------
! Read one dataset of particle positions from the maureparticle file.
!----------------------------------------------------------------------
subroutine readTimeVaryingParticlePositions(fmd, p, mp, isnap)
use asgsio
use adcmesh, only : station_t
use logging
implicit none
type(fileMetaData_t), intent(inout) :: fmd
integer, intent(in) :: iSnap ! dataset counter
integer, intent(in) :: mp ! max number of particles
type(station_t), intent(inout) :: p(mp) ! particles
integer :: lineNum ! line number counter
integer :: ip ! particle counter
integer :: errorIO
!
lineNum=0
do ip=1,fmd%numParticlesPerSnap(iSnap)
   lineNum = lineNum + 1
   read(unit=fmd%fun,fmt=*,end=482,err=802,iostat=errorIO) p(ip)%iID, p(ip)%lon, p(ip)%lat, fmd%timesec(iSnap), p(ip)%elementIndex
   p(ip)%elementFound = .true.
   p(ip)%z = 0.d0 ! TODO: could provide options for setting this
end do
return

! jump to here when end of file is reached unexpectedly
482 write(scratchMessage,'("Unexpectedly encountered end-of-file when reading from the Maureparticle file ",a,".")') trim(fmd%dataFileName)
! jump to here when encountering i/o error when reading Maureparticle file
call allMessage(ERROR,scratchMessage)
802 write(scratchMessage,'("readTimeVaryingParticlePositions: Attempted to read line ",i0," from the maureparticle file ",a," when an i/o error occurred. The Fortran error code was ",i0,".")') lineNum, trim(fmd%dataFileName), errorIO
call allMessage(ERROR,scratchMessage)
stop
!----------------------------------------------------------------------
end subroutine readTimeVaryingParticlePositions
!----------------------------------------------------------------------


!----------------------------------------------------------------------
!                     S U B R O U T I N E
!             W R I T E   T I M E   V A R Y I N G
!             P A R T I C L E   P O S I T I O N S
!----------------------------------------------------------------------
! Writes one dataset of particle positions to the XDMF xml file.
!----------------------------------------------------------------------
subroutine writeTimeVaryingParticlePositions(fmd, p, mp, iSnap, olun)
use asgsio, only : fileMetaData_t
use ioutil, only : ind
use adcmesh, only : station_t
implicit none
type(fileMetaData_t), intent(inout) :: fmd
integer, intent(in) :: mp ! max number of particles
type(station_t), intent(inout) :: p(mp) ! particles
integer, intent(in) :: iSnap  ! dataset to work on
integer, intent(in) :: olun   ! i/o unit number of xdmf xml file
integer :: ip ! particle counter

write(olun,'('//ind('|')//',a,i0,a)') '<Topology TopologyType="POLYVERTEX" NumberOfElements="',fmd%numParticlesPerSnap(iSnap),'" NodesPerElement="1"/>'
write(olun,'('//ind('|')//',a)') '<Geometry GeometryType="XYZ">'
write(olun,'('//ind('+')//',a,i0,a)') '<DataItem ItemType="Uniform" Dimensions="',fmd%numParticlesPerSnap(iSnap),' 3" Format="XML">'
do ip=1,fmd%numParticlesPerSnap(iSnap)
   write(olun,'('//ind('|')//',f15.7,f15.7,f15.7)') p(ip)%lon, p(ip)%lat, p(ip)%z
end do
write(olun,'('//ind('|')//',a)')      '</DataItem>'
write(olun,'('//ind('-')//',a)') '</Geometry>'
!----------------------------------------------------------------------
end subroutine writeTimeVaryingParticlePositions
!----------------------------------------------------------------------


!----------------------------------------------------------------------
!                     S U B R O U T I N E
!            I N T E R P O L A T E   A N D   W R I T E
!     T I M E   V A R Y I N G   A T T R I B U T E S   X M L
!----------------------------------------------------------------------
! Reads data array(s) defined on an adcirc mesh at a particular time,
! interpolates them to the current particle positions, and writes the
! interpolated data set(s) to XDMF xml.
!----------------------------------------------------------------------
subroutine interpolateAndWriteTimeVaryingAttributesXML(afmd, pfmd, m, p, mp, iSnap, olun)
use asgsio
use adcmesh
use ioutil, only : ind, check
implicit none
! TODO: this assumes the same number of datasets in each file and that
! the datasets correspond to the same times in seconds
type(fileMetaData_t), intent(inout) :: afmd ! datafile containing attribute values on mesh
type(fileMetaData_t), intent(inout) :: pfmd ! datafile containing particle positions
type(mesh_t), intent(inout) :: m
integer, intent(in) :: mp ! max number of particles
type(station_t), intent(inout) :: p(mp) ! particles
integer, intent(in) :: iSnap  ! dataset to work on
integer, intent(in) :: olun   ! i/o unit number of xdmf xml file
real(8), allocatable :: adcirc_data(:,:) ! (np,numComponents)
real(8), allocatable :: interpVals(:,:)  ! interpolated values (numComp,numParticles)
real(8), allocatable :: sp(:) ! particle speeds for 2D velocity
integer :: nc_start(2) ! node number and dataset to start the reading
integer :: nc_count(2) ! number of nodes and datasets to read in
character(len=100) :: attributeType
logical :: dryNode ! true if the node is dry and values there are undefined
integer :: i ! netcdf variable counter
integer :: k ! particle counter
integer :: v ! variable counter
integer :: node ! node counter
!
! read the attribute values: assume multiple attribute values in a single
! netcdf file are a multicomponent dataset (i.e., a vector)
allocate(adcirc_data(m%np,afmd%numVarNetCDF))
nc_start = (/ 1, iSnap /)
nc_count = (/ m%np, 1 /)
call check(nf90_open(trim(afmd%dataFileName), NF90_NOWRITE, afmd%nc_id))
do v=1,afmd%numVarNetCDF
   !write(6,*) 'afmd%nc_id=',afmd%nc_id,' afmd%varID(v)=',afmd%nc_varID(v),' v=',v,' afmd%numVarNetCDF=',afmd%numVarNetCDF,' iSnap=',iSnap
   call check(nf90_get_var(afmd%nc_id,afmd%ncds(v)%nc_varID,adcirc_data(:,v),nc_start,nc_count))
end do
call check(nf90_close(afmd%nc_id))
if (trim(afmd%ncds(1)%varNameNetCDF).eq.'u-vel') then
   allocate(sp(pfmd%numParticlesPerSnap(iSnap))) ! for computing velocity magnitudes
endif
!
! compute the interpolation weights for all particles in this snap
do k=1,pfmd%numParticlesPerSnap(iSnap)
   call computeStationWeights(p(k), m)
end do
!
! for each component, look up the data values at the three nodes of
! the resident element and linearly interpolate them at the particle
! position
allocate(interpVals(afmd%numVarNetCDF,pfmd%numParticlesPerSnap(iSnap)))
do v=1,afmd%numVarNetCDF
   do k=1,pfmd%numParticlesPerSnap(iSnap)
      ! look up the three nodes that make up this element
      do node=1,3
         p(k)%n(node) = m%nm(p(k)%elementIndex,node)
      end do
      dryNode = .false.
      ! search for dry or undefined nodal values
      if (p(k)%elementIndex.ne.0) then
         do node=1,3
            if ( adcirc_data(p(k)%n(node),v).eq.-99999 ) then
               dryNode = .true. ! at least one of the three nodes has an undefined value
            endif
         end do
      endif
      if (p(k)%elementIndex.eq.0 .or. dryNode.eqv..true.) then
         interpVals(v,k) = -99999.0
      else
         interpVals(v,k) = 0.d0
         ! now interpolate this variable using the weights at the three nodes
         do node=1,3
            interpVals(v,k) = interpVals(v,k) + adcirc_data(p(k)%n(node),v) * p(k)%w(node)
         enddo
      endif
   end do
end do
!
! now write the interpolated values to XDMF xml
attributeType = "Scalar"
if (afmd%numVarNetCDF.gt.1) then
   attributeType = "Vector"
endif
!
! TODO: This assumes that if the netcdf contains a multicomponent quantity
! (e.g., a 2D vector) that there is only one XDMF variable name to describe
! this quantity
write(olun,'('//ind('|')//',A)') '<Attribute Name="'//trim(afmd%xds(1)%varNameXDMF)//'" AttributeType="'//trim(attributeType)//'" Center="Node">'
write(olun,'('//ind('+')//',a,i0,a)')    '<DataItem DataType="Float" Dimensions="',pfmd%numParticlesPerSnap(iSnap),' 3" Format="XML">'
do k=1,pfmd%numParticlesPerSnap(iSnap)
   ! TODO: Fix this hack for 2D velocity
   if (trim(afmd%ncds(1)%varNameNetCDF).eq.'u-vel') then
      ! fill in zero for the third component : velocity in the z direction
!      write(olun,'('//ind('|')//',f15.7,2x,f21.15,2x,f15.7)') (interpVals(v,k), v=1,afmd%numVarNetCDF), 0.d0
      write(olun,*) (interpVals(v,k), v=1,afmd%numVarNetCDF), 0.d0
      ! compute particle speeds while we're at it
      sp(k) = sqrt(interpVals(1,k)**2 + interpVals(2,k)**2)
   else
      write(olun,'('//ind('|')//',f15.7,f15.7,f15.7)') (interpVals(v,k), v=1,afmd%numVarNetCDF)
   endif
end do
write(olun,'('//ind('|')//',a)')    '</DataItem>'
write(olun,'('//ind('-')//',a)') '</Attribute>'
! write an extra attribute containing the particle speeds
if (trim(afmd%ncds(1)%varNameNetCDF).eq.'u-vel') then
   write(olun,'('//ind('|')//',a)') '<Attribute AttributeType="Scalar" Center="Node" Name="particle_speed">'
   write(olun,'('//ind('+')//',a,i0,a)')  '<DataItem DataType="Float" Dimensions="',pfmd%numParticlesPerSnap(iSnap),' 1" Format="XML">'
   do k=1,pfmd%numParticlesPerSnap(iSnap)
      write(olun,'('//ind('|')//',f15.7)') sp(k)
   end do
   write(olun,'('//ind('|')//',a)')    '</DataItem>'
   write(olun,'('//ind('-')//',a)') '</Attribute>'
endif
deallocate(adcirc_data)
if (trim(afmd%ncds(1)%varNameNetCDF).eq.'u-vel') then
   deallocate(sp)
endif
deallocate(interpVals)
!----------------------------------------------------------------------
end subroutine interpolateAndWriteTimeVaryingAttributesXML
!----------------------------------------------------------------------
