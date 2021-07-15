!------------------------------------------------------------------
! addMeshToNetCDF: Add adcirc mesh data to an existing
! netCDF data file.
!------------------------------------------------------------------
! Copyright(C) 2021 Jason Fleming
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
!------------------------------------------------------------------
! Compile with accompanying makefile.
!------------------------------------------------------------------
program addMeshToNetCDF
use netcdf
use asgsio
use ioutil
use logging
use adcmesh
implicit none
type(mesh_t) :: m
type(meshNetCDF_t) :: n
type(fileMetaData_t) :: f  ! adcirc file to be read and converted
character(len=2048) :: errorVar
logical :: deflate ! true if compiled with support for internal file compression in netcdf files
integer :: errorIO
integer :: i
!
! initializations
if (loggingInitialized.eqv..false.) then
   call initLogging(availableUnitNumber(),'adcirc2netcdf.f90')
endif
#if NETCDF_CAN_DEFLATE
   deflate = .true.
#else
   deflate = .false.
#endif
m%meshFileName = "fort.14"
f%dataFileFormat = NETCDF4
f%dataFileName = "null"
!
write(6,'(a,a)') "INFO: addMeshToNetCDF was compiled with the following netcdf library: ", &
   trim(nf90_inq_libvers())
argcount = command_argument_count() ! count up command line options
if (argcount.gt.0) then
   i=0
   do while (i.lt.argcount)
      i = i + 1
      call getarg(i, cmdlineopt)
      select case(trim(cmdlineopt))
         case("--meshfile")
            i = i + 1
            call getarg(i, cmdlinearg)
            write(6,'(a,a,a,a,a)') "INFO: Processing ",trim(cmdlineopt)," ",trim(cmdlinearg),"."
            m%meshFileName = trim(cmdlinearg)
         case("--datafile")
            i = i + 1
            call getarg(i, cmdlinearg)
            write(6,'(a,a,a,a,a)') "INFO: Processing ",trim(cmdlineopt)," ",trim(cmdlinearg),"."
            f%dataFileName = trim(cmdlinearg)
         case default
            write(6,'(a,a,a)') "WARNING: Command line option '",TRIM(cmdlineopt),"' was not recognized."
      end select
   end do
end if
!
! open existing netcdf file
write(6,'(a,a,a)') "INFO: Opening NetCDF file '"//trim(f%dataFileName)//"'."
call checkFileExistence(f%dataFileName,errorIO)
if (errorIO.ne.0) then
    write(6,'(a,a,a)') "ERROR: The NetCDF file '"//trim(f%dataFileName)//"' was not found."
    stop
endif
call check(nf90_open(trim(f%dataFileName), NF90_WRITE, f%nc_id))
! read ascii mesh file and add defs to netcdf
call read14(m)
call check(nf90_redef(f%nc_id))
call writeMeshDefinitionsToNetCDF(m, n, f%nc_id, deflate)
! end variable and attributes definitions
call check(nf90_enddef(f%nc_id))
! place mesh-related data into the file
call writeMeshDataToNetCDF(m, n, f%nc_id)
! close the file
call check(nf90_close(f%nc_id))
write(6,'(a)') 'INFO: Only mesh data were written.'
!----------------------------------------------------------------------
end program addMeshToNetCDF
!----------------------------------------------------------------------


