!--------------------------------------------------------------------------
! asgsio.f90
!
! A module that provides helper subroutines for opening and reading
! ADCIRC files in ascii and netcdf format.
!--------------------------------------------------------------------------
! Copyright(C) 2014--2019 Jason Fleming
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
!--------------------------------------------------------------------------
module asgsio
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
use netcdf
implicit none
!
! Derived data type to represent a netcdf variable within an ADCIRC-related
! data file.
type netCDFVar_t
   logical :: isInteger     ! true for integer variable
   logical :: isElemental   ! true if the variable is defined on elements
   logical :: is3D          ! true if data varies horizontally and vertically
   integer :: numValuesPerDataset ! ne or np depending on isElemental

   integer :: nc_dimid(2)
   integer :: nc_varID ! netcdf variable ID for targetted variables
   character(NF90_MAX_NAME) :: varNameNetCDF ! variable names inside files
   ! netcdf variable type (NF90_DOUBLE etc) for targetted variables
   integer :: nc_varType
   ! netcdf metadata attributes associated with a variable
   integer :: numVarAtt ! number of attributes associated with a variable
   ! netcdf type for variable-associated metadata
   integer, allocatable :: nc_varAttType(:)  ! (numVarAtt)
   ! netcdf name (keyword) for variable-associated metadata
   character(NF90_MAX_NAME), allocatable :: nc_varAttName(:) ! (numVarAtt)
   real(8) :: fillValue     ! missing float data value, usually -99999.d0
   integer :: ifillValue    ! missing integer data value, usually -99999
   integer, allocatable :: idata(:) ! single dataset at particular time
   real(8), allocatable :: rdata(:) ! single dataset at particular time
   integer, allocatable :: idata3D(:,:) ! (np, nfen) ! single 3D dataset at particular time
   real(8), allocatable :: rdata3D(:,:) ! (np, nfen) ! single 3D dataset at particular time
   integer, pointer :: mapping(:) ! used for mapping fulldomain<-->subdomain
end type netCDFVar_t
!
! Derived data type to represent an xdmf variable within an ADCIRC-related
! data file.
type xdmfVar_t
   !character(NF90_MAX_NAME), allocatable :: varNameXDMF(:)   ! as represented in XDMF XML
   !character(NF90_MAX_NAME), allocatable :: varNameXDMF   ! as represented in XDMF XML
   character(NF90_MAX_NAME) :: varNameXDMF   ! as represented in XDMF XML
   ! the following refer to scalar or vector quantities in XDMF files
   character(len=20) :: dataCenter ! "Node" or "Element"
   character(len=20) :: dataRank ! e.g. "2DVector"
   character(len=20) :: numberType   ! "Int" or "Float"
   integer :: numberPrecision         ! 4 or 8
   integer :: numComponents
   integer :: xmlReference  ! for use in XInclude statements
   ! corresponding netcdf variable names for each xdmf component
   character(NF90_MAX_NAME), allocatable :: ncVarName(:) ! (numComponents)
end type xdmfVar_t
!
! Derived data type to represent ADCIRC-related data files.
type fileMetaData_t
   !
   ! state
   logical :: initialized  ! .true. if memory has been allocated
   !
   ! general file characteristics
   character(len=2048) :: dataFileName ! full path
   character(len=100) :: defaultFileName ! fort.14 for mesh file, etc
   integer :: dataFileCategory ! DOMAIN, STATION, NODALATTR, MINMAX, etc
   integer :: dataFileFormat     ! ASCII, NETCDF4, XDMF etc parameters defined above
   character(len=1024) :: fileTypeDesc ! analyst-readable description
   integer :: nSnaps           ! number of datasets in the time varying file
   logical :: timeOfOccurrence ! .true. if min/max file has time of occurrence data
   integer :: irtype ! for ascii adcirc files, 1=scalar, 2=2D vector, 3=3D vector
   integer :: fun     ! file i/o unit number (ascii files of any kind)
   !
   ! netcdf files of any kind
   integer :: nc_id        ! netcdf ID for the file
   integer :: ncFileType   ! e.g. NF90_NOCLOBBER etc
   integer :: nvar         ! total number of variables in the netcdf file
   integer :: ndim         ! total number of dimensions in the netcdf file
   integer :: natt         ! total number of attributes in the netcdf file
   integer :: nc_dimid_time ! netcdf ID for the time dimension
   integer :: nc_varid_time ! netcdf ID for the time array
   integer :: nc_varid_it   ! netcdf ID for the time step array
   integer :: ncformat      ! netcdf3 or netcdf4
   integer :: numVarNetCDF ! number of variables targetted in NetCDF4 file
   integer, allocatable :: nc_attType(:) ! netcdf variable type for global metadata
   character(NF90_MAX_NAME), allocatable :: nc_attName(:) ! netcdf attribute name for global metadata
   !
   ! ascii adcirc files only
   character(len=1000) :: agridRunIDRunDesLine ! 1st header line in time varying output files
   logical :: isSparse    ! true for sparse ascii
   logical :: isInteger     ! true for integer variable
   logical :: isElemental   ! true if the variable is defined on elements
   logical :: is3D          ! true if data varies horizontally and vertically
   integer :: nspool        ! time steps between datasets
   real(8) :: time_increment !  time (s) between datasets
   real(8) :: defaultValue      ! missing data value for sparse real data
   integer :: idefaultValue    ! missing data value for sparse integer data
   integer :: numValuesPerDataSet  ! np (number of nodes) for nodal data or ne for elemental
   integer :: nStations     ! only for station files
   character(len=50), allocatable :: dataFileStationIDs(:) ! namelen from adcirc is 50
   integer, allocatable :: idata(:,:) ! (irtype, numValuesPerDataSet)
   real(8), allocatable :: rdata(:,:) ! (irtype, numValuesPerDataSet)
   integer, allocatable :: idata3D(:,:,:) ! (irtype, numValuesPerDataSet, nfen)
   real(8), allocatable :: rdata3D(:,:,:) ! (irtype, numValuesPerDataSet, nfen)
   integer, pointer :: mapping(:) ! used for mapping fulldomain<-->subdomain
   !
   ! netcdf adcirc files only
   integer :: nc_dimid_station ! netcdf ID for the station dimension
   integer :: nc_dimid_namelen ! netcdf ID for the station length dimension
   integer :: station_namelen  ! length of netcdf station name variable
   integer :: nc_varid_station ! netcdf ID for the station IDs
   character(len=120) :: datenum ! e.g. seconds since 2008-07-31 12:00:00 +00:00
   integer, allocatable :: it(:) ! time step number associated with each dataset
   type(netCDFVar_t), allocatable :: ncds(:)
   !
   ! xdmf files only
   character(len=2048) :: xmfFile ! name of XDMF XML file
   integer :: xmfUnit      ! logical unit number of XDMF XML file
   integer :: numVarXDMF   ! number of variables as represented in XDMF XML
   type(xdmfVar_t), allocatable :: xds(:)
   !
   ! particle files only
   integer :: maxParticles  ! max number of particles at any one time
   integer, allocatable :: numParticlesPerSnap(:) ! (nsnaps)num part in each snap
   !
   ! owi files only (netcdf or ascii)
   logical :: isGridded     ! true if the data are defined on a regular grid (e.g.OWI)
   logical :: isBasin       ! true if the data represent basin scale (OWI)
   logical :: isRegion      ! true if the data represent region scale (OWI)
   integer :: NC_DimID_x
   integer :: NC_DimID_y
   integer :: NC_Start_OWI(3)
   integer :: NC_Count_OWI(3)
   integer :: NC_VarID_owibp
   integer :: NC_VarID_owibvx
   integer :: NC_VarID_owibvy
   integer :: NC_VarID_owirp
   integer :: NC_VarID_owirvx
   integer :: NC_VarID_owirvy
   integer :: nc_dimid_grid(3)
   integer :: iLatOWI
   integer :: iLonOWI
   !
   ! data characteristics and metadata
   logical :: timeVarying   ! .true. if we have datasets at different times
   logical :: useCPP        ! .true. if metadata should refer to CPP coordinates
   real(8), allocatable :: timesec(:)  ! time in seconds associated with each dataset
end type fileMetaData_t

type netCDFMetaDataFromExternalFile_t
   integer :: nmUnit ! i/o unit number for netcdf metadata attributes file
   integer :: nmatt  ! number of netcdf metadata attributes in the file
   character(NF90_MAX_NAME), allocatable :: matt(:,:) ! key/value pair of metadata attributes
   character(NF90_MAX_NAME) :: nmattFileName
   integer :: lineNum ! number of lines in the external netcdf metadata file
   character(len=120) :: datenum ! e.g. seconds since 2008-07-31 12:00:00 +00:00
   integer :: numValuesPerDataset ! for ascii files, should equal np in associated mesh file
end type netCDFMetaDataFromExternalFile_t

type realVector1D_t
   integer :: n    ! current number of elements
   integer :: s    ! total number of memory slots to hold elements
   integer :: ninc ! number of elements to add when more memory is needed
   real(8), allocatable :: v(:) ! array of values in the vector
   real(8), allocatable :: vtemp(:) ! temp array of values during reallocation
end type realVector1D_t

type integerVector1D_t
   integer :: n    ! current number of elements
   integer :: s    ! total number of memory slots to hold elements
   integer :: ninc ! number of elements to add when more memory is needed
   integer, allocatable :: v(:) ! array of values in the vector
   integer, allocatable :: vtemp(:) ! temp array of values during reallocation
end type integerVector1D_t

type characterVector1D_t
   integer :: n    ! current number of elements
   integer :: s    ! total number of memory slots to hold elements
   integer :: ninc ! number of elements to add when more memory is needed
   character(len=2000), allocatable :: v(:) ! array of values in the vector
   character(len=2000), allocatable :: vtemp(:) ! temp array of values during reallocation
end type characterVector1D_t

character(len=80) :: rundes  ! 1st line in adcirc fort.15 input file
character(len=80) :: runid   ! 2nd line in adcirc fort.15 input file
!
! mapping arrays
! subdomain -> fulldomain index number mapping of each resultshape node
integer, allocatable, target :: sub2fullNodes(:)
! fulldomain -> subdomain index mapping of the resultshape nodes
integer, allocatable, target :: full2subNodes(:)
! subdomain -> fulldomain index number mapping of element in resultshape
integer, allocatable, target :: sub2fullElements(:)
! fulldomain -> subdomain index mapping
integer, allocatable, target :: full2subElements(:)

!-----------
!-----------
contains
!-----------
!-----------

!----------------------------------------------------------------------
!----------------------------------------------------------------------
!----------------------------------------------------------------------
subroutine allocateDatasetMemory(f, m)
use ioutil
use logging
use adcmesh
implicit none
type(fileMetaData_t), intent(inout) :: f
type(mesh_t), intent(in) :: m
integer :: c ! component counter
!
select case(f%dataFileFormat)
case(NETCDFG,NETCDF3,NETCDF4)
   do c=1,f%numVarNetCDF
      if ( (m%is3D.eqv..true.).and.(f%ncds(c)%is3D.eqv..true.) ) then
         allocate(f%ncds(c)%rdata3D(f%ncds(c)%numValuesPerDataSet,m%nfen))
      else
         if (f%ncds(c)%isInteger.eqv..true.) then
            allocate(f%ncds(c)%idata(f%ncds(c)%numValuesPerDataset))
         else
            allocate(f%ncds(c)%rdata(f%ncds(c)%numValuesPerDataset))
         endif
      endif
   end do
case(ASCII,SPARSE_ASCII,ASCIIG) ! memory allocation for subdomain ascii datasets
   if ( (m%is3D.eqv..true.).and.(f%is3D.eqv..true.) ) then
      allocate(f%rdata3D(f%irtype,f%numValuesPerDataSet,m%nfen))
   else
      if (f%isInteger.eqv..true.) then
         allocate(f%idata(f%irtype,f%numValuesPerDataset))
      else
         allocate(f%rdata(f%irtype,f%numValuesPerDataset))
      endif
   endif
case default
   call allMessage(ERROR,'Cannot convert full domain files with this format.')
   stop
end select
!----------------------------------------------------------------------
end subroutine allocateDatasetMemory
!----------------------------------------------------------------------

!----------------------------------------------------------------------
!                  S U B R O U T I N E
! D E T E R M I N E   N E T C D F   F I L E   C H A R A C T E R I S T I C S
!----------------------------------------------------------------------
! jgf: Determine type and contents of adcirc data (output) files.
!----------------------------------------------------------------------
subroutine determineNetCDFFileCharacteristics(f, m, n)
use adcmesh
use logging
use ioutil
use nodalattr
implicit none
type(fileMetaData_t), intent(inout) :: f
type(mesh_t), intent(inout) :: m
type(meshNetCDF_t), intent(inout) :: n
character(len=NF90_MAX_NAME) :: thisVarName
character(len=NF90_MAX_NAME) :: componentName
character(len=NF90_MAX_NAME) :: nodalAttributesComment ! locally declare this here to avoid dependency on nodalattr module
integer :: numNodalAttributes  ! locally declare this here to avoid dependency on nodalattr module
integer :: i, j, k, p, q
integer :: errorIO
logical :: exists ! true if the file exists

call allMessage(INFO,'Determining netCDF file characteristics.')
!
! set some defaults
f%isGridded = .false.        ! true if e.g. OWI
f%timeVarying = .true.       ! initialize to most common value
f%timeOfOccurrence = .false. ! only relevant to min/max files
f%irtype = 1
f%defaultFileName = 'null'
f%dataFileCategory = UNKNOWN
f%fileTypeDesc = 'null description'
f%isBasin = .false.
f%isRegion = .false.
f%timeOfOccurrence = .false. ! only relevant to min/max files
f%numValuesPerDataSet = -99
!
! open the netcdf file
call checkFileExistence(f%dataFilename, errorIO)
if (errorIO.ne.0) then
   stop
endif
call check(nf90_open(trim(f%dataFileName), NF90_NOWRITE, f%nc_id))
!
! set the agrid value (mesh comment line)
m%agrid='agrid:not_set'
call readMeshCommentLineNetCDF(m, f%nc_id)
!
! determine the type of data stored in the file
call check(nf90_inquire(f%nc_id, f%ndim, f%nvar, f%natt, f%nc_dimid_time, f%ncformat))
if ( (f%ncformat.eq.nf90_format_netcdf4).or. &
   (f%ncformat.eq.nf90_format_netcdf4_classic) ) then
   call allMessage(INFO,'The data file uses netcdf4 formatting.')
   if (f%nc_dimid_time.lt.0) then
      f%timeVarying = .false.
	   ! check to see if it is a nodal attributes file
	   errorIO = nf90_get_att(f%nc_id,nf90_global,'nodalAttributesComment',nodalAttributesComment)
	   if (errorIO.eq.0) then
         call allMessage(INFO,'The netcdf file '//trim(f%dataFileName)//' is a nodal attributes file.')
	      f%defaultFileName = 'fort.13'
	      f%dataFileCategory = NODALATTRIBF
	      f%fileTypeDesc = 'an ADCIRC nodal attributes ('//trim(f%defaultFileName)//') file.'
          call allMessage(INFO,'Examining '//trim(f%fileTypeDesc)//' file.')
	   else
          errorIO = nf90_inquire_dimension(f%nc_id,f%nc_dimid_time,len=f%nSnaps)
          if ( errorIO.ne.0 ) then
             if ( f%nvar.lt.6 ) then
                call allMessage(INFO,'The netcdf file '//trim(f%dataFileName)//' only contains mesh data.')
                f%dataFileCategory = MESH !FIXME: or fort.88?
             endif
          endif
	   endif
   endif
endif
!
! if the file only contains a mesh, then adcmesh.f90 will pick up
! all the characteristics, so close the file and return
if (f%dataFileCategory.eq.MESH) then
   call check(nf90_close(f%nc_id))
   return
endif
!
! determine the number of snapshots in the file
if ( f%timeVarying.eqv..true. ) then
   call check(nf90_inquire_dimension(f%nc_id,f%nc_dimid_time,len=f%nSnaps))
   write(scratchMessage,'(a,i0,a)') 'There is/are ',f%nSnaps,' dataset(s) in the file.'
   call allMessage(INFO,scratchMessage)
   if (f%nSnaps.eq.0) then
     write(scratchMessage,'(a,a,a)') 'The file "',trim(f%dataFileName),'" does not contain any data sets.'
     call allMessage(ERROR,scratchMessage)
     stop 1
   endif
   !
   !  get time
   !
   ! load up the time values (in seconds)
   allocate(f%timesec(f%nSnaps))
   allocate(f%it(f%nSnaps))
   call check(nf90_inq_varid(f%nc_id, "time", f%NC_VarID_time))
   call check(nf90_get_var(f%nc_id, f%NC_VarID_time, f%timesec, (/ 1 /), (/ f%nSnaps /) ))
   call check(nf90_get_att(f%nc_id,f%nc_varid_time,'units',f%datenum))
   !
   ! is it a station file?
   f%dataFileCategory = UNKNOWN
   do i=1,f%nvar
      call check(nf90_inquire_variable(f%nc_id, i, thisVarName))
      if (trim(thisVarName).eq.'station_name') then
         f%dataFileCategory = STATION
         call check(nf90_inq_dimid(f%nc_id, "station", f%nc_dimid_station))
      endif
   end do
endif
! if this is not a station file, find the mesh node dimension and comment
if ( f%dataFileCategory.ne.STATION ) then
   call readMeshCommentLineNetCDF(m, f%nc_id)
   ! determine the number of nodes
   call check(nf90_inq_dimid(f%nc_id, "node", n%nc_dimid_node))
   if (f%dataFileCategory.ne.NODALATTRIBF) then
      f%dataFileCategory = DOMAIN ! most common value, can be changed below
   endif
endif
!
! determine the type of data in the netcdf file, and set the
! file metadata accordingly
do i=1,f%nvar
   if ( f%dataFileCategory.eq.NODALATTRIBF ) then
      f%timeVarying = .false.
      numNodalAttributes = 0
      ! count the number of nodal attributes
      do j=1, f%nvar
         call check(nf90_inquire_variable(f%nc_id, j, thisVarName))
         select case(trim(thisVarName))
         case('mannings_n_at_sea_floor')
            numNodalAttributes = numNodalAttributes + 1
            f%numVarNetCDF = f%numVarNetCDF + 1
            f%numVarXDMF = f%numVarXDMF + 1
         case('primitive_weighting_in_continuity_equation')
            numNodalAttributes = numNodalAttributes + 1
            f%numVarNetCDF = f%numVarNetCDF + 1
            f%numVarXDMF = f%numVarXDMF + 1
         case('surface_canopy_coefficient')
            numNodalAttributes = numNodalAttributes + 1
            f%numVarNetCDF = f%numVarNetCDF + 1
            f%numVarXDMF = f%numVarXDMF + 1
         case('surface_directional_effective_roughness_length')
            numNodalAttributes = numNodalAttributes + 1
            f%numVarNetCDF = f%numVarNetCDF + 1
            f%numVarXDMF = f%numVarXDMF + 12 ! hardcoded to 12
         case('surface_submergence_state')
            numNodalAttributes = numNodalAttributes + 1
            f%numVarNetCDF = f%numVarNetCDF + 1
            f%numVarXDMF = f%numVarXDMF + 1
         case default
            ! something other than a nodal attribute
         end select
      end do
      ! allocate space to hold the metadata for all the nodal attributes
      call initFileMetaData(f, thisVarName, f%numVarNetCDF, f%numVarXDMF)
      k=1
      p=1
      do j=1, f%nvar
         call check(nf90_inquire_variable(f%nc_id, j, thisVarName))
         select case(trim(thisVarName))
         case('mannings_n_at_sea_floor','primitive_weighting_in_continuity_equation','surface_canopy_coefficient','surface_submergence_state')
            f%ncds(k)%varNameNetCDF = trim(thisVarName)
            k = k + 1
            f%xds(p)%varNameXDMF = trim(thisVarName)
            p = p + 1
         case('surface_directional_effective_roughness_length')
            f%ncds(k)%varNameNetCDF = trim(thisVarName)
            k = k + 1
            do q=1,12 ! hardcoded to 12
               ! form component name
               write(componentName,'(a,"[",i2.2,"]")') trim(thisVarName), q
               f%xds(p)%varNameXDMF = trim(componentName)
               f%xds(p)%numComponents = -12  ! negative indicates hyperslab, not vector
               p = p + 1
            end do
         case default
            ! something other than a nodal attribute
         end select
      end do
      exit
   endif
   call check(nf90_inquire_variable(f%nc_id, i, thisVarName))
   select case(trim(thisVarName))
   case("u-vel3D","v-vel3D","w-vel3D")
      f%defaultFileName = 'fort.45'
      f%fileTypeDesc = 'an ADCIRC 3D water current velocity ('//trim(f%defaultFileName)//') file.'
      call initFileMetaData(f, thisVarName, 3, 1)
      f%ncds(2)%varNameNetCDF = "v-vel3D"
      f%ncds(3)%varNameNetCDF = "w-vel3D"
      f%irtype = 3
      f%xds(1)%numComponents = 3
      f%xds(1)%varNameXDMF = "currentVel3D"
      exit
   case("zeta")
      if ( f%dataFileCategory.eq.STATION ) then
         f%defaultFileName = 'fort.61'
         f%fileTypeDesc = 'a time varying 2D ADCIRC water surface elevation station file (fort.61)'
      else
         f%defaultFileName = 'fort.63'
         f%fileTypeDesc = 'a time varying 2D ADCIRC water surface elevation file (fort.63)'
      endif
      call initFileMetaData(f, thisVarName, 1, 1)
      exit
   case("eta1")
      f%defaultFileName = 'eta1.63'
      f % fileTypeDesc = 'a time varying 2D ADCIRC water surface elevation at previous time step file (eta1.63)'
      call initFileMetaData(f, thisVarName, 1, 1)
      exit
   case("eta2")
      f%defaultFileName = 'eta2.63'
      f % fileTypeDesc = 'a time varying 2D ADCIRC water surface elevation at current time step file (eta2.63)'
      call initFileMetaData(f, thisVarName, 1, 1)
      exit
   case("tk")
      f%defaultFileName = 'tk.63'
      f % fileTypeDesc = 'a time varying 2D bottom friction file (tk.63)'
      call initFileMetaData(f, thisVarName, 1, 1)
      exit
   case("offset")
      if ( f%dataFileCategory.eq.STATION ) then
         f%defaultFileName = 'offset.61'
         f % fileTypeDesc = 'a time varying water level offset station file (offset.61)'
      else
         f%defaultFileName = 'offset.63'
         f % fileTypeDesc = 'a time varying water level offset file (offset.63)'
      endif
      call initFileMetaData(f, thisVarName, 1, 1)
      exit
   case("tau0")
      f%defaultFileName = 'fort.90'
      f % fileTypeDesc = 'a time varying tau0 file (fort.90)'
      call initFileMetaData(f, thisVarName, 1, 1)
      exit
   case("coefdiagonal")
      f%defaultFileName = 'coefdiagonal.63'
      f % fileTypeDesc = 'a fully consistent ADCIRC LHS matrix diagonal file (coefdiagonal.63)'
      call initFileMetaData(f, thisVarName, 1, 1)
      exit
   case("coefele")
      f%defaultFileName = 'coefele.100'
      f % fileTypeDesc = 'an element mass matrix coefficient file (coefele.100)'
      call initFileMetaData(f, thisVarName, 1, 1)
      f % ncds(1)%isElemental = .true.
      f % xds(1)%dataCenter = 'Cell' ! noff
      exit
   case("nodecode")
      f%defaultFileName = 'nodecode.63'
      f % fileTypeDesc = 'a node wet/dry state file (nodecode.63)'
      call initFileMetaData(f, thisVarName, 1, 1)
      f % ncds(1)%isInteger = .true.
      exit
   case("noff")
      f%defaultFileName = 'noff.100'
      f % fileTypeDesc = 'an element wet/dry state file (noff.100)'
      call initFileMetaData(f, thisVarName, 1, 1)
      f % ncds(1)%isInteger = .true.
      f % xds(1)%dataCenter = 'Cell' ! noff
      exit
   case("dryelementareacheck")
      f%defaultFileName = 'dryelementareacheck.100'
      f % fileTypeDesc = 'a dry element area check (dryelementareacheck.100)'
      call initFileMetaData(f, thisVarName, 1, 1)
      f % xds(1)%dataCenter = 'Cell' ! noff
      exit
   case("nneighele")
      f%defaultFileName = 'nneighele.63'
      f % fileTypeDesc = 'a number of elemental neighbors attached to each node file (nneighele.63)'
      call initFileMetaData(f, thisVarName, 1, 1)
      f % ncds(1)%isInteger = .true.
      f % timeVarying = .false.
      exit
   case("nodeids")
      f%defaultFileName = 'nodeids.63'
      f % fileTypeDesc = 'a fortran indexed node IDs file (nodeids.63)'
      call initFileMetaData(f, thisVarName, 1, 1)
      f % timeVarying = .false.
      f % ncds(1)%isInteger = .true.
      exit
   case("elementids")
      f%defaultFileName = 'elementids.100'
      f % fileTypeDesc = 'a fortran indexed element IDs file (elementids.100)'
      call initFileMetaData(f, thisVarName, 1, 1)
      f % xds(1)%dataCenter = 'Cell' ! element IDs
      f % ncds(1)%isInteger = .true.
      f % ncds(1)%isElemental = .true.
      f % timeVarying = .false.
      exit
   case("zetad")
      f%defaultFileName = 'fort.67.68'
      f%dataFileCategory = HOTSTART
      f % fileTypeDesc = 'a 2D ADCIRC hotstart file (fort.67/fort.68)'
      f % timeVarying = .false.
      call initFileMetaData(f, thisVarName, 7, 6)
      f % ncds(1)%varNameNetCDF = "zeta1"  ! eta1
      f % ncds(2)%varNameNetCDF = "zeta2"  ! eta2
      f % ncds(3)%varNameNetCDF = "zetad"  ! EtaDisc
      f % ncds(4)%varNameNetCDF = "u-vel"  ! uu2 \_combine as vector in XDMF_
      f % ncds(5)%varNameNetCDF = "v-vel"  ! vv2 /
      f % ncds(6)%varNameNetCDF = "nodecode"  ! nodecode
      f % ncds(6)%isInteger = .true.  ! nodecode
      f % ncds(7)%varNameNetCDF = "noff"   ! noff<---element/cell centered
      f % ncds(7)%isInteger = .true.  ! noff<---element/cell centered
      f % ncds(7)%isElemental = .true.  ! noff<---element/cell centered
      !
      f % xds(4) % numComponents = 2
      f%xds(4)%varNameXDMF = "currentVel2D"
      exit
   case("u-vel","v-vel")
      if ( f%dataFileCategory.eq.STATION ) then
         f%defaultFileName = 'fort.62'
         f%fileTypeDesc = 'a 2D ADCIRC water current velocity station file (fort.62)'
      else
         f%defaultFileName = 'fort.64'
         f%fileTypeDesc = 'a 2D ADCIRC water current velocity file (fort.64)'
      endif
      call initFileMetaData(f, thisVarName, 2, 1)
      f%ncds(1)%varNameNetCDF = "u-vel"  ! uu2 in ADCIRC
      f%ncds(2)%varNameNetCDF = "v-vel"  ! vv2 in ADCIRC
      f%irtype = 2
      f%xds(1)%numComponents = 2
      f%xds(1)%varNameXDMF = "currentVel2D"
      exit
   case("uu1-vel","vv1-vel")
      f%defaultFileName = 'uu1vv1.64'
      f % fileTypeDesc = 'a 2D ADCIRC water current velocity at previous time step file (uu1vv1.64)'
      call initFileMetaData(f, thisVarName, 2, 1)
      f % ncds(1)%varNameNetCDF = "uu1-vel"  ! uu1 in ADCIRC
      f % ncds(2)%varNameNetCDF = "vv1-vel"  ! vv1 in ADCIRC
      f % xds(1) % varNameXDMF = 'water_current_velocity_at_previous_timestep'
      f%irtype = 2
      f%xds(1)%numComponents = 2
      f%xds(1)%varNameXDMF = "prevCurrentVel2D"
      exit
   case("pressure")
      if ( f%dataFileCategory.eq.STATION ) then
         f%defaultFileName = 'fort.71'
         f%fileTypeDesc = "an ADCIRC barometric pressure station file (fort.71)"
      else
         f%defaultFileName = 'fort.73'
         f%fileTypeDesc = "an ADCIRC barometric pressure file (fort.73)"
      endif
      call initFileMetaData(f, thisVarName, 1, 1)
      exit
   case("windx","windy")
      if ( f%dataFileCategory.eq.STATION ) then
          f%defaultFileName = 'fort.72'
          f%fileTypeDesc = "an ADCIRC wind velocity file (fort.72)"
      else
          f%defaultFileName = 'fort.74'
          f%fileTypeDesc = "an ADCIRC wind velocity file (fort.74)"
      endif
      call initFileMetaData(f, thisVarName, 2, 1)
      f % ncds(1)%varNameNetCDF = "windx"
      f % ncds(2)%varNameNetCDF = "windy"
      f%irtype = 2
      f%xds(1)%numComponents = 2
      f%xds(1)%varNameXDMF = "windVel"
      exit
   case("maxele","zeta_max")
      f % dataFileCategory = MINMAX
      f%defaultFileName = 'maxele.63'
      f % fileTypeDesc = "an ADCIRC maximum water surface elevation (maxele.63) file"
      ! Check to see if this is a newer-style min/max file that records
      ! the time of the min or max, and if so, prepare to convert the
      ! time of occurrence metadata as well.
      call initMinMaxFileMetaData(f, thisVarName, .true.)
      exit
   case("initial_river_elevation")
      f % dataFileCategory = INITRIVER
      f%defaultFileName = 'fort.88'
      f % fileTypeDesc = "an ADCIRC initial river elevation (fort.88) file"
      call initFileMetaData(f, thisVarName, 1, 1)
      exit
   case("eslnodes")
      f % dataFileCategory = ESLNODES
      f%defaultFileName = 'ESLNodes.63'
      f % fileTypeDesc = "an ADCIRC elemental slope limiter (ESLNodes.63) file"
      call initFileMetaData(f, thisVarName, 1, 1)
      exit
   case("maxwvel","wind_max")
      f % dataFileCategory = MINMAX
      f%defaultFileName = 'maxwvel.63'
      f % fileTypeDesc = "an ADCIRC maximum wind speed (maxwvel.63) file"
      call initMinMaxFileMetaData(f, thisVarName, .true.)
      exit
   case("maxvel","vel_max")
      f % dataFileCategory = MINMAX
      f%defaultFileName = 'maxvel.63'
      f % fileTypeDesc = "an ADCIRC maximum current speed (maxvel.63) file"
      call initMinMaxFileMetaData(f, thisVarName, .true.)
      exit
   case("maxrs","radstress_max")
      f % dataFileCategory = MINMAX
      f%defaultFileName = 'maxrs.63'
      f % fileTypeDesc = "an ADCIRC maximum wave radiation stress gradient (maxrs.63) file"
      call initMinMaxFileMetaData(f, thisVarName, .true.)
      exit
   case("minpr","pressure_min")
      f % dataFileCategory = MINMAX
      f%defaultFileName = 'minpr.63'
      f % fileTypeDesc = "an ADCIRC minimum barometric pressure (minpr.63) file"
      call initMinMaxFileMetaData(f, thisVarName, .true.)
      exit
   case("endrisinginun")
      f % dataFileCategory = MINMAX
      f%defaultFileName = 'endrisinginun.63'
      f % fileTypeDesc = "an ADCIRC nodes with inundation rising at end of simulation (endrisinginun.63) file"
      call initMinMaxFileMetaData(f, thisVarName, .true.)
      exit
   case("initiallydry")
      f % dataFileCategory = MINMAX
      f%defaultFileName = 'initiallydry.63'
      f % fileTypeDesc = "an ADCIRC dry nodes at cold start (initiallydry.63) file"
      call initMinMaxFileMetaData(f, thisVarName, .true.)
      exit
   case("inundationmask")
      f % dataFileCategory = MINMAX
      f%defaultFileName = 'inundationmask.63'
      f % fileTypeDesc = "an ADCIRC inundation mask (inundationmask.63) file"
      call initMinMaxFileMetaData(f, thisVarName, .true.)
      f % timeVarying = .false.
      exit
   case("inun_time")
      f % dataFileCategory = MINMAX
      f%defaultFileName = 'inundationtime.63'
      f % fileTypeDesc = "an ADCIRC total time inundated (inundationtime.63) file"
      call initMinMaxFileMetaData(f, thisVarName, .true.)
      exit
   case("everdried")
      f % dataFileCategory = MINMAX
      f%defaultFileName = 'everdried.63'
      f % fileTypeDesc = "an ADCIRC ever dried (everdried.63) file"
      call initMinMaxFileMetaData(f, thisVarName, .true.)
      exit
   case("inun_max")
      f % dataFileCategory = MINMAX
      f%defaultFileName = 'maxinundepth.63'
      f % fileTypeDesc = "an ADCIRC maximum inundation depth (maxinundepth.63) file"
      call initMinMaxFileMetaData(f, thisVarName, .true.)
      exit
   case("radstress_x","radstress_y")
      f%defaultFileName = 'rads.64'
      f % fileTypeDesc = "an ADCIRC wave radiation stress gradient (rads.64) file"
      call initfileMetaData(f, thisVarName, 2, 1)
      f % ncds(1)%varNameNetCDF = "radstress_x"
      f % ncds(2)%varNameNetCDF = "radstress_y"
      f%irtype = 2
      f%xds(1)%numComponents = 2
      f%xds(1)%varNameXDMF = "radstress"
   case("swan_DIR")
      f%defaultFileName = 'swan_DIR.63'
      f % fileTypeDesc = "a SWAN wave direction (swan_DIR.63) file"
      call initFileMetaData(f, thisVarName, 1, 1)
      exit
   case("swan_HS")
      f%defaultFileName = 'swan_HS.63'
      f % fileTypeDesc = "a SWAN significant wave height (swan_HS.63) file"
      call initFileMetaData(f, thisVarName, 1, 1)
      exit
   case("swan_HS_max")
      f%defaultFileName = 'swan_HS_max.63'
      f % dataFileCategory = MINMAX
      f % fileTypeDesc = "a SWAN maximum significant wave height (swan_HS_max.63) file"
      call initMinMaxFileMetaData(f, thisVarName, .true.)
      exit
   case("swan_TMM10")
      f%defaultFileName = 'swan_TMM10.63'
      f % fileTypeDesc = "a SWAN mean absolute wave period (swan_TMM10.63) file"
      call initFileMetaData(f, thisVarName, 1, 1)
      exit
   case("swan_TM01")
      f%defaultFileName = 'swan_TMM01.63'
      f % fileTypeDesc = "SWAN mean absolute wave period (swan_TM01.63) file"
      call initFileMetaData(f, thisVarName, 1, 1)
      exit
   case("swan_TM02")
      f%defaultFileName = 'swan_TMM02.63'
      f % fileTypeDesc = "a SWAN mean absolute zero crossing period (swan_TM02.63) file"
      call initFileMetaData(f, thisVarName, 1, 1)
      exit
   case("swan_TPS")
      f%defaultFileName = 'swan_TPS.63'
      f % fileTypeDesc = "a SWAN smoothed peak period (swan_TPS.63) file"
      call initFileMetaData(f, thisVarName, 1, 1)
      exit
   case("swan_TPS_max")
      f%defaultFileName = 'swan_TPS_max.63'
      f % dataFileCategory = MINMAX
      f % fileTypeDesc = "a SWAN maximum smoothed peak period (swan_TPS_max.63) file"
      call initMinMaxFileMetaData(f, thisVarName, .true.)
      exit
   case("ESLNodes")
      f%defaultFileName = 'ESLNodes.63'
      f % fileTypeDesc = "an elemental slope limiter active nodes (ESLNodes.63) file"
      call initFileMetaData(f, thisVarName, 1, 1)
      exit
   case("swan_windx","swan_windy")
      f%defaultFileName = 'swan_WIND.64'
      f % fileTypeDesc = "a SWAN wind velocity (swan_WIND.64) file"
      call initFileMetaData(f, thisVarName, 2, 1)
      f % ncds(1)%varNameNetCDF = "swan_windx"
      f % ncds(2)%varNameNetCDF = "swan_windy"
      f%irtype = 2
      f%xds(1)%numComponents = 2
      f%xds(1)%varNameXDMF = "swan_wind"
      exit
   case default
      cycle     ! did not recognize this variable name
   end select
end do
!
! check to see if we did not recognize any of the variables in the file
if ( f%initialized.eqv..false. ) then
   call allMessage(INFO,'Did not recognize any of the variables in the file '//trim(f%dataFileName)//'.')
   call check(nf90_close(f%nc_id))
   f%dataFileCategory = MESH
   return
endif
!
! if this is not a station file, find the mesh node dimension and
! comment
if ( f%dataFileCategory.ne.STATION) then
   ! determine the number of nodes
   call check(nf90_inq_dimid(f%nc_id, "node", n%nc_dimid_node))
   call check(nf90_inquire_dimension(f%nc_id, n%nc_dimid_node, len=m%np))
else
   ! determine the number of stations
   call check(nf90_inq_dimid(f%nc_id, "station", f%nc_dimid_station))
   call check(nf90_inquire_dimension(f%nc_id, f%nc_dimid_station, len=f%nStations))
   call check(nf90_inq_dimid(f%nc_id, "namelen", f%nc_dimid_namelen))
   call check(nf90_inquire_dimension(f%nc_id, f%nc_dimid_namelen, len=f%station_namelen))
endif
!
! set the number of values per dataset
if ( f%dataFileCategory.eq.STATION ) then
   f%numValuesPerDataSet = f%nStations ! for use with ascii files
   do i=1, f%numVarNetCDF
      f%ncds(i)%numValuesPerDataSet = f%nStations
   end do
else
   f%numValuesPerDataSet = m%np ! general case for ascii files
   do i=1, f%numVarNetCDF
      f%ncds(i)%numValuesPerDataSet = m%np ! general case
      if (f%ncds(i)%isElemental) then
         f%ncds(i)%numValuesPerDataSet = m%ne
         f%numValuesPerDataSet = m%ne ! for ascii files
      endif
   end do
endif
!
! get the variable id(s) of the data we want to convert
do i=1,f%numVarNetCDF
   call check(nf90_inq_varid(f%nc_id, f%ncds(i)%varNameNetCDF, f%ncds(i)%nc_varid))
end do
!
! set the default values rundes and runid attributes in case they need to be written
! to ascii output
rundes = 'rundes' !TODO: make adcirc write this value to all netcdf output files
runid = 'runid'   !TODO: make adcirc write this value to all netcdf output files
!
! Get all the global metadata attribute names and their netcdf data types.
! This depends on initialization of file metadata and memory allocation
! performed for the file in the select case construct above.
allocate(f%nc_attName(f%natt))
allocate(f%nc_attType(f%natt))

do i=1, f%natt
   ! determine netcdf attribute types
   call check(nf90_inq_attname(f%nc_id, nf90_global, i, f%nc_attName(i)))
   if (trim(f%nc_attName(i)).eq.'rundes') then
      call check(nf90_get_att(f%nc_id, nf90_global, f%nc_attName(i), rundes))
      !write(*,*) trim(rundes)
   endif
   if (trim(f%nc_attName(i)).eq.'runid') then
      call check(nf90_get_att(f%nc_id, nf90_global, f%nc_attName(i), runid))
      !write(*,*) trim(runid)
   endif
   call check(nf90_inquire_attribute(f%nc_id, nf90_global, f%nc_attName(i), f%nc_attType(i)))
end do
!
! determine the number of metadata attributes associated with each variable
! and allocate memory for them
do i=1, f%numVarNetCDF
   call check(nf90_inq_varid(f%nc_id, f%ncds(i)%varNameNetCDF, f%ncds(i)%nc_varID))
   call check(nf90_inquire_variable(f%nc_id, f%ncds(i)%nc_varID, f%ncds(i)%varNameNetCDF, nAtts=f%ncds(i)%numVarAtt))
   allocate(f%ncds(i)%nc_varAttType(f%ncds(i)%numVarAtt))
   allocate(f%ncds(i)%nc_varAttName(f%ncds(i)%numVarAtt))
end do
!
! get the netcdf metadata attribute names and types associated with each variable
do i=1, f%numVarNetCDF
   do j=1, f%ncds(i)%numVarAtt
      ! get attribute name
      call check(nf90_inq_attname(f%nc_id, f%ncds(i)%nc_varID, j, f%ncds(i)%nc_varAttName(j)))
      ! determine netcdf attribute type
      call check(nf90_inquire_attribute(f%nc_id, f%ncds(i)%nc_varID, f%ncds(i)%nc_varAttName(j), f%ncds(i)%nc_varAttType(j)))
   end do
end do
!
! determine time increment between output writes
f%time_increment = -99999.d0
f%defaultValue = -99999.d0
f%nspool = -99999
if ( (f%dataFileCategory.ne.NODALATTRIBF).and.f%timeVarying.eqv..true. ) then
   if ( (f%nSnaps.gt.1).and.(f%timeOfOccurrence.eqv..false.) ) then
      f%time_increment = f%timesec(2) - f%timesec(1)
   endif
   if ( f%dataFileCategory.ne.MINMAX ) then
      f%it(:) = -99999
   endif
endif
!
call check(nf90_close(f%nc_id))
call allMessage(INFO,'Finished determining netCDF file characteristics.')

!----------------------------------------------------------------------
end subroutine determineNetCDFFileCharacteristics
!----------------------------------------------------------------------

!----------------------------------------------------------------------
!                S U B R O U T I N E
!  D E T E R M I N E   A S C I I   F I L E   C H A R A C T E R I S T I C S
!----------------------------------------------------------------------
! Uses the default file name to determine file category and
! characteristics.
!----------------------------------------------------------------------
subroutine determineASCIIFileCharacteristics(fn)
use ioutil
use logging
implicit none
type(fileMetaData_t), intent(inout) :: fn ! netcdf file to write metadata attributes to
! owi or gridded dataset associated variables
character(len=1000) :: owiheader
character(len=2048) :: errorVar
integer(8) :: date1
integer(8) :: date2
real(8) :: dxOWI
real(8) :: dyOWI
real(8) :: swLatOWI
real(8) :: swLonOWI
integer :: iLatOWI
integer :: iLonOWI
integer :: iMinOWI
integer :: iCYMDHOWI
integer :: numNodesNonDefault ! number of nodes with nondefault values in 1st sparse dataset
real(8) :: defaultValue ! default value for nodes not listed in sparse dataset
real(8) :: snapr ! time (s) associated with first data set
integer :: snapi ! time step number associated with first data set
integer :: errorIO
character(len=160) :: line
integer :: lineNum
!
call allMessage(INFO,'Determining characteristics of ASCII text file.')
!
! set some defaults
fn%nSnaps = -99
fn%numValuesPerDataSet = -99
fn%time_increment = -99.d0
fn%nspool = -99
fn%irtype = -99
fn%timeVarying = .true.
fn%isGridded = .false.
fn%isElemental = .false.
fn%is3D = .false.
fn%isInteger = .false.
fn%fileTypeDesc = 'null description'
fn%isBasin = .false.
fn%isRegion = .false.
fn%timeOfOccurrence = .false. ! only relevant to min/max files
if ( fn%dataFileCategory.eq.MAUREPT ) then
   return
endif
fn%dataFileCategory = DOMAIN
!
! determine data file category from default file name
select case(trim(fn%defaultFileName))
case('maxele.63','maxvel.63','maxwvel.63','maxrs.63','minpr.63','swan_HS_max.63','swan_TPS_max.63','minmax')
   fn%dataFileCategory = MINMAX
   fn%timeVarying = .false.
   call allMessage(INFO,'Found min/max file.')
case('fort.13','nodalattributes')
   fn%dataFileCategory = NODALATTRIBF
   fn%timeVarying = .false.
case('fort.14','mesh','grid','fort.grd')
   fn%dataFileCategory = MESH
   fn%timeVarying = .false.
case('fort.88')
   fn%dataFileCategory = INITRIVER
   fn%timeVarying = .false.
case('fort.221','fort.222','owi')
   fn%dataFileCategory = OWI
   fn%isGridded = .true.
   fn%isBasin = .true.
case('fort.223','fort.224')
   fn%dataFileCategory = OWI
   fn%isGridded = .true.
   fn%isRegion = .true.
case('fort.51','fort.52','fort.61','fort.62','fort.71','fort.72','station')
   fn%dataFileCategory = STATION
case('fort.41','fort.42','fort.43','station3D')
   fn%dataFileCategory = STATION
   fn%is3D = .true.
case('fort.44','fort.45','fort.46')
   fn%is3D = .true.
case('dryelementareacheck.100')
   fn%isElemental = .true.
   fn%timeVarying = .false.
case('elementids.100')
   fn%isElemental = .true.
   fn%timeVarying = .false.
   fn%isInteger = .true.
case('coefele.100')
   fn%isElemental = .true.
case('nodecode.63')
   fn%isInteger = .true.
case('nneighele.63','nodeids.63')
   fn%isInteger = .true.
   fn%timeVarying = .false.
case('noff.100')
   fn%isElemental = .true.
   fn%isInteger = .true.
case('ESLNodes.63')
   fn%timeVarying = .false.
   fn%fileTypeDesc = 'elemental slope limiter activation at nodes file'
   fn%nSnaps = 1
case default
   fn%dataFileCategory = DOMAIN
   call allMessage(INFO,'Found full domain time varying output file.')
end select
!
! open the file and determine the number of datasets, sparseness, etc
lineNum=1
select case(fn%dataFileCategory)
case(MINMAX,STATION,DOMAIN)
   fn%fun = availableUnitNumber()
   call allMessage(INFO,'Checking number of nodes in data file.')
   lineNum = 1
   call openFileForRead(fn%fun, trim(fn%dataFileName), errorIO)
   read(fn%fun,*,end=246,err=248,iostat=errorio) fn%agridRunIDRunDesLine
   lineNum=lineNum+1
   call allMessage(INFO,'The ASCII text file header line is ' // trim(fn%agridRunIDRunDesLine) // '.')
   read(fn%fun,*,end=246,err=248,iostat=errorio) fn%nSnaps, fn%numValuesPerDataset, fn%time_increment, fn%nspool, fn%irtype
   lineNum=lineNum+1
   write(scratchMessage,23) fn%nSnaps, fn%numValuesPerDataset, fn%time_increment, fn%nspool, fn%irtype
   call allMessage(INFO,scratchMessage)
23 format('The number of datasets is ',i0,'; the number of values per dataset is ',i0,'; the time increment between datasets is ',f15.8,'; the time step increment between datasets is ',i0,'; the rank of the dataset is ',i0,'.')
   if (fn%dataFileCategory.eq.MINMAX.and.fn%nSnaps.eq.2) then
      fn%timeOfOccurrence = .true. ! only relevant to min/max files
      call allMessage(INFO,'The min/max file contains time of occurrence data.')
   endif
   read(fn%fun,'(a)',end=246,err=248) line
   lineNum = lineNum + 1
   ! determine whether the file is sparse ascii
   fn%isSparse = .false.
   ! attempt to parse this line as full ascii
   read(Line,*,end=246,err=248,iostat=errorio) snapr, snapi
   ! attempt to parse this line as sparse ascii
   read(line,*,err=907,end=907) snapr, snapi, numNodesNonDefault, defaultValue
   fn%isSparse = .true.
   call allMessage(INFO,'The ASCII file is sparse formatted.')
907 continue
   close(fn%fun)
case(INITRIVER)
   fn%agridRunIDRunDesLine = 'null'
   fn%irtype = 1
case(MAUREPT)
   fn%fileTypeDesc = 'a time varying maureparticle output file'
case(OWI)
   ! open the file and read the header
   fn%fun = availableUnitNumber()
   call openFileForRead(fn%fun, trim(fn%dataFileName), errorIO)
   owiheader(:) = ' '  !set owiheader to blanks before read
   errorVar = "owiheader"
   read(fn%fun, fmt='(a80)',end=246,err=248,iostat=errorIO) owiheader
   call checkErrOWI(errorIO,errorVar,fn%defaultFileName)
   errorVar = "start date"
   read(owiheader(56:65),'(i10)',end=246,err=248,iostat=errorIO) date1
   call checkErrOWI(errorIO,errorVar,fn%defaultFileName)
   errorVar = "end date"
   read(owiheader(71:80),'(i10)',end=246,err=248,iostat=errorIO) date2
   call checkErrOWI(errorIO,errorVar,fn%defaultFileName)
   !
   ! Read grid specifications/date
   errorVar = "grid specifications/date"
   read (fn%fun,11,end=246,err=248,iostat=errorIO) iLatOWI,iLonOWI,dxOWI,dyOWI,swlatOWI,swlonOWI,iCYMDHOWI,iMinOWI
11  format(t6,i4,t16,i4,t23,f6.0,t32,f6.0,t44,f8.0,t58,f8.0,t69,i10,i2)
   write(scratchMessage,'("iLatOWI=",i0," iLonOWI=",i0" dxOWI=",f6.0," dyOWI=",f6.0," swlatOWI=",f8.0," swlonOWI=",f8.0," iCYMDHOWI=",i0," iMinOWI=",i0)') iLatOWI,iLonOWI,dxOWI,dyOWI,swlatOWI,swlonOWI,iCYMDHOWI,iMinOWI
   call allMessage(INFO,scratchMessage)
   close(fn%fun)
   !FIXME: finish code for parsing OWI data
case default
   fn%nSnaps = -99
   fn%numValuesPerDataSet = -99
   fn%time_increment = -99.d0
   fn%nspool = -99
   fn%irtype = -99
end select
!
return
      ! We jump to this section if there was an error reading a file.
246 call allMessage(ERROR,'Unexpectedly reached end-of-file.') ! END jumps here
248 call allMessage(ERROR,'I/O error during file access.')     ! ERR jumps here
write(scratchMessage,'(a,i0,a,a,a)') 'Attempted to read line ',lineNum,' in file '//trim(fn%dataFileName)//'.' ! ERR jumps here
call allMessage(ERROR,scratchMessage)
write(scratchMessage,'(a,i0,a)') 'The numerical code of the i/o error was ',errorio,'.'
call allMessage(ERROR,scratchMessage)
stop

!----------------------------------------------------------------------
end subroutine determineASCIIFileCharacteristics
!----------------------------------------------------------------------


!----------------------------------------------------------------------
!                S U B R O U T I N E
!    A D D   D A T A   A T T R I B U T E S   N E T C D F
!----------------------------------------------------------------------
! jgf : Adds attributes for netcdf cf compliance based on the type
! of data to be written into the file. Requires an intialized mesh.
!----------------------------------------------------------------------
subroutine addDataAttributesNetCDF(fn, m, n)
use ioutil
use logging
use adcmesh
implicit none
type(fileMetaData_t), intent(inout) :: fn ! netcdf file to write metadata attributes to
type(mesh_t), intent(inout) :: m
type(meshNetCDF_t), intent(inout) :: n
character(NF90_MAX_NAME) :: thisVarName
integer :: nc_dimid(2)
integer :: i
!
write(6,*) 'INFO: Adding data attributes to netCDF file.' !jgfdebug
!
! set the number of values per dataset
if ( fn % dataFileCategory .eq. STATION ) then
   nc_dimid = (/ fn%nc_dimid_station, fn%nc_dimID_Time /)
else
   nc_dimid = (/ n%nc_dimid_node, fn%nc_dimID_Time /)
   if ( fn%timeVarying.eqv..false.) then
      nc_dimid = n%nc_dimid_node
   endif
endif
!
select case(fn%dataFileCategory)
case(OWI)
   select case(trim(fn%defaultFileName))
   case('fort.221')
      thisVarName = 'basinpressure'
      call initFileMetaData(fn, thisVarName, 1, 1)
      call check(nf90_def_var(fn%nc_id,fn%ncds(1)%varNameNetCDF,nf90_double,fn%nc_dimid_grid,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillvalue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','air pressure at sea level on basin grid'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','air_pressure_basin_grid'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','mbar'))
   case('fort.223')
      thisVarName = 'regionpressure'
      call initFileMetaData(fn, thisVarName, 1, 1)
      call check(nf90_def_var(fn%nc_id,fn%ncds(1)%varNameNetCDF,nf90_double,fn%nc_dimid_grid,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillvalue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','air pressure at sea level on region grid'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','air_pressure_region_grid'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','mbar'))
   case('fort.222')
      thisVarName = 'basinwindx'
      call initFileMetaData(fn, thisVarName, 2, 1)
      call check(nf90_def_var(fn%nc_id,thisVarName,nf90_double,fn%nc_dimid_grid,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','e/w wind velocity on basin grid'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','eastward_wind_basin_grid'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','m s-1'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'positive','east'))
      fn%ncds(2)%varNameNetCDF = 'basinwindy'
      call check(nf90_def_var(fn%nc_id,'basinwindy',nf90_double,fn%nc_dimid_grid,fn%ncds(2)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'long_name','n/s wind velocity on basin grid'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'standard_name','nortward_wind_basin_grid'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'units','m s-1'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'positive','north'))
   case('fort.224')
      thisVarName = 'regionwindx'
      call initFileMetaData(fn, thisVarName, 2, 1)
      fn%irtype = 2
      call check(nf90_def_var(fn%nc_id,'regionwindx',nf90_double,fn%nc_dimid_grid,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','e/w wind velocity on region grid'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','eastward_wind_region_grid'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','m s-1'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'positive','east'))
      fn%ncds(2)%varNameNetCDF = 'regionwindy'
      call check(nf90_def_var(fn%nc_id,'regionwindy',nf90_double,fn%nc_dimid_grid,fn%ncds(2)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'long_name','n/s wind velocity on region grid'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'standard_name','nortward_wind_region_grid'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'units','m s-1'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'positive','north'))
   case default
      call allMessage(ERROR,'OWI file type not recognized.')
      stop
   end select
case(DOMAIN)
   select case(trim(fn%defaultFileName))
   case('fort.63') !63
      thisVarName = 'zeta'
      call initFileMetaData(fn, thisVarName, 1, 1)
      !write(6,*) nc_dimid(1), nc_dimid(2), fn%ncds(1)%nc_varID ! jgfdebug
      call check(nf90_def_var(fn%nc_id,'zeta',nf90_double,nc_dimid,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','water surface elevation above geoid'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','water_surface_elevation'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','m'))
   case('fort.69') !63
      thisVarName = 'zeta'
      call initFileMetaData(fn, thisVarName, 1, 1)
      !write(6,*) nc_dimid(1), nc_dimid(2), fn%ncds(1)%nc_varID ! jgfdebug
      call check(nf90_def_var(fn%nc_id,'zeta',nf90_double,nc_dimid,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','water surface elevation above geoid'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','water_surface_elevation'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','m'))
   case('eta1.63')
      thisVarName = 'eta1'
      call initFileMetaData(fn, thisVarName, 1, 1)
      call check(nf90_def_var(fn%nc_id,'eta1',nf90_double,nc_dimid,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','water surface elevation above geoid at previous time step'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','water_surface_elevation_at_previous_timestep'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','m'))
   case('eta2.63')
      thisVarName = 'eta2'
      call initFileMetaData(fn, thisVarName, 1, 1)
      call check(nf90_def_var(fn%nc_id,'eta2',nf90_double,nc_dimid,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','water surface elevation above geoid at current time step'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','water_surface_elevation_at_current_timestep'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','m'))
   case('tk.63')
      thisVarName = 'tk'
      call initFileMetaData(fn, thisVarName, 1, 1)
      call check(nf90_def_var(fn%nc_id,'tk',nf90_double,nc_dimid,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','bottom friction force'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','bottom_friction_force'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','m'))
   case('fort.90')
      thisVarName = 'tau0'
      call initFileMetaData(fn, thisVarName, 1, 1)
      call check(nf90_def_var(fn%nc_id,'tau0',nf90_double,nc_dimid,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','time varying tau0'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','time_varying'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','1'))
   case('offset.63') !63
      thisVarName = 'offset'
      call initFileMetaData(fn, thisVarName, 1, 1)
      call check(nf90_def_var(fn%nc_id,'offset',nf90_double,nc_dimid,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','water level offset'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','water_level'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','m h2o'))
   case('fort.64')
      thisVarName = 'u-vel'
      call initFileMetaData(fn, thisVarName, 2, 1)
      fn%irtype = 2
      call check(nf90_def_var(fn%nc_id,'u-vel',nf90_double,nc_dimid,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','water column vertically averaged east/west velocity'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','eastward_water_velocity'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','m s-1'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'positive','east'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'dry_value',-99999.0d0))
      fn%ncds(2)%varNameNetCDF = 'v-vel'
      call check(nf90_def_var(fn%nc_id,'v-vel',nf90_double,nc_dimid,fn%ncds(2)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'long_name','water column vertically averaged north/south velocity'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'standard_name','northward_water_velocity'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'units','m s-1'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'positive','north'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'dry_value',-99999.0d0))
   case('uu1vv1.64')
      thisVarName = 'uu1-vel'
      call initFileMetaData(fn, thisVarName, 2, 1)
      fn%irtype = 2
      call check(nf90_def_var(fn%nc_id,'uu1-vel',nf90_double,nc_dimid,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','water column vertically averaged east/west velocity at previous time step'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','eastward_water_velocity_at_previous_time_step'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','m s-1'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'positive','east'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'dry_value',-99999.0d0))
      fn%ncds(2)%varNameNetCDF = 'vv1-vel'
      call check(nf90_def_var(fn%nc_id,'vv1-vel',nf90_double,nc_dimid,fn%ncds(2)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'long_name','water column vertically averaged north/south velocity at previous time step'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'standard_name','northward_water_velocity_at_previous_time_step'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'units','m s-1'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'positive','north'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'dry_value',-99999.0d0))
   case('fort.73') !73
      thisVarName = 'pressure'
      call initFileMetaData(fn, thisVarName, 1, 1)
      call check(nf90_def_var(fn%nc_id,'pressure',nf90_double,nc_dimid,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','air pressure at sea level'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','airressure_at_sea_level'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','meters of water'))
   case('fort.74') !74
      thisVarName = 'windx'
      call initFileMetaData(fn, thisVarName, 2, 1)
      fn%irtype = 2
      call check(nf90_def_var(fn%nc_id,'windx',nf90_double,nc_dimid,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','e/w wind velocity'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','eastward_wind'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','m s-1'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'positive','east'))
      fn%ncds(2)%varNameNetCDF = 'windy'
      call check(nf90_def_var(fn%nc_id,'windy',nf90_double,nc_dimid,fn%ncds(2)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'long_name','n/s wind velocity'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'standard_name','northward_wind'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'units','m s-1'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'positive','north'))
   case('swan_dir.63') !dir
      thisVarName = 'swan_dir'
      call initFileMetaData(fn, thisVarName, 1, 1)
      call check(nf90_def_var(fn%nc_id,'swan',nf90_double,nc_dimid,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','wave direction'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','sea_surface_wave_direction'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','degrees_cw_from_east'))
   case('swan_hs.63') !hs
      thisVarName = 'swan_hs'
      call initFileMetaData(fn, thisVarName, 1, 1)
      call check(nf90_def_var(fn%nc_id,'swan_hs',nf90_double,nc_dimid,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','significant wave height'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','sea_surface_wave_significant_height'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','m'))
   case('swan_tmm10.63') !tmm10
      thisVarName = 'swan_tmm10'
      call initFileMetaData(fn, thisVarName, 1, 1)
      call check(nf90_def_var(fn%nc_id,'swan_tmm10',nf90_double,nc_dimid,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','mean period'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','sea_surface_wave_mean_period_from_variance_spectral_density_inverse_frequency_moment'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','s'))
   case('swan_tps.63') !tps
      thisVarName = 'swan_tps'
      call initFileMetaData(fn, thisVarName, 1, 1)
      call check(nf90_def_var(fn%nc_id,'swan_tps',nf90_double,nc_dimid,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','peak period'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','maximum_sea_surface_wave_period_at_variance_spectral_density_maximum'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','s'))
   case('coefdiagonal.63')
      thisVarName = 'coefdiagonal'
      call initFileMetaData(fn, thisVarName, 1, 1)
      call check(nf90_def_var(fn%nc_id,'coefdiagonal',nf90_double,nc_dimid,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','adcirc fully consistent left hand side matrix diagonal coefficients'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','adcirc_fully_consistent_lhs_diagonal '))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','unitless'))
   case('nodecode.63')
      thisVarName = 'nodecode'
      call initFileMetaData(fn, thisVarName, 1, 1)
      fn%ncds(1)%nc_varType = nf90_int
      call check(nf90_def_var(fn%nc_id,'nodecode',fn%ncds(1)%nc_varType,nc_dimid,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','node wet or dry'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','node_wet_or_dry'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','unitless'))
   case('noff.100')
      thisVarName = 'noff'
      call initFileMetaData(fn, thisVarName, 1, 1)
      fn%ncds(1)%isElemental = .true.
      fn%ncds(1)%nc_varType = nf90_int
      call check(nf90_def_var(fn%nc_id,'noff',fn%ncds(1)%nc_varType,(/ n%nc_dimid_nele, fn%nc_dimid_time /),fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','element wet or dry'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','element_wet_or_dry'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','element'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','unitless'))
   case('dryelementareacheck.100')
      thisVarName = 'dryelementareacheck'
      call initFileMetaData(fn, thisVarName, 1, 1)
      fn%ncds(1)%nc_varType = nf90_int
      fn%ncds(1)%isElemental = .true.
      call check(nf90_def_var(fn%nc_id,'dryelementareacheck',fn%ncds(1)%nc_varType,n%nc_dimid_nele,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','dry element area check'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','dry_element_area_check'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','element'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','unitless'))
   case('coefele.100')
      thisVarName = 'coefele'
      call initFileMetaData(fn, thisVarName, 1, 1)
      fn%ncds(1)%isElemental = .true.
      call check(nf90_def_var(fn%nc_id,'coefele',nf90_double,(/ n%nc_dimid_nele, fn%nc_dimid_time /),fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','element contribution to mass matrix diagonal'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','element_coef'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','element'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','unitless'))
   case('nneighele.63')
      thisVarName = 'nneighele'
      call initFileMetaData(fn, thisVarName, 1, 1)
      fn%ncds(1)%nc_varType = nf90_int
      call check(nf90_def_var(fn%nc_id,'nneighele',fn%ncds(1)%nc_varType,nc_dimid,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','number of element neighbors for each node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','num_element_neighbors'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','unitless'))
   case('nodeids.63')
      thisVarName = 'nodeids'
      call initFileMetaData(fn, thisVarName, 1, 1)
      fn%ncds(1)%nc_varType = nf90_int
      call check(nf90_def_var(fn%nc_id,'nodeids',fn%ncds(1)%nc_varType,nc_dimid,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','fortran indexed node ids'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','fortran_indexed_node_ids'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','unitless'))
   case('elementids.100')
      thisVarName = 'elementids'
      call initFileMetaData(fn, thisVarName, 1, 1)
      fn%ncds(1)%nc_varType = nf90_int
      fn%ncds(1)%isElemental = .true.
      call check(nf90_def_var(fn%nc_id,'elementids',fn%ncds(1)%nc_varType,n%nc_dimid_nele,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','fortran indexed element ids'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','fortran_indexed_element_ids'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','element'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','unitless'))
   case('ESLNodes.63','eslnodes.63') ! eslnodes.63
      thisVarName = 'eslnodes'
      call initFileMetaData(fn, thisVarName, 1, 1)
      call check(nf90_def_var(fn%nc_id,'eslnodes',nf90_double,n%nc_dimid_node,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','elemental slope limiter active nodes'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name', &
         'elemental_slope_limiter_active_nodes'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','1'))
   case('fort.88')
      thisVarName = 'initial_river_elevation'
      call initFileMetaData(fn, thisVarName, 1, 1)
      call check(nf90_def_var(fn%nc_id,'initial_river_elevation',nf90_double,n%nc_dimid_node,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','initial river elevation'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','initial_river_elevation'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','m'))
   case default
      call allMessage(ERROR,'Domain output data file type not recognized. Default data file name is '//trim(fn%defaultFileName)//'.')
      stop
   end select
case(MINMAX)
   select case(trim(fn%defaultFileName))
   case('maxele.63') !maxele
      thisVarName = 'zeta_max'
      call initMinMaxFileMetaData(fn, thisVarName, .false.)
      call check(nf90_def_var(fn%nc_id,'zeta_max',nf90_double,n%nc_dimid_node,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','maximum sea surface elevation above datum'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','maximum_sea_surface_elevation_above_datum'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','m'))
      if ( fn%timeOfOccurrence.eqv..true.) then
         call check(nf90_def_var(fn%nc_id,'time_of_zeta_max',nf90_double,n%nc_dimid_node,fn%ncds(2)%nc_varID))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'_fillValue',-99999.d0))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'long_name','time of maximum sea surface elevation above datum'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'standard_name','time_of_maximum_sea_surface_elevation_above_datum'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'coordinates','y x'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'location','node'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'mesh','adcirc_mesh'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'units','s'))
      endif
   case('maxwvel.63') ! maxwvel
      thisVarName = 'wind_max'
      call initMinMaxFileMetaData(fn, thisVarName, .false.)
      call check(nf90_def_var(fn%nc_id,'wind_max',nf90_double,n%nc_dimid_node,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','maximum wind speed at sea level'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','maximum_wind_speed_at_sea_level'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','m s-1'))
      if ( fn%timeOfOccurrence.eqv..true.) then
         call check(nf90_def_var(fn%nc_id,'time_of_wind_max',nf90_double,n%nc_dimid_node,fn%ncds(2)%nc_varID))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'_fillValue',-99999.d0))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'long_name','time of maximum wind speed at sea level'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'standard_name','time_of_maximum_wind_speed_at_sea_level'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'coordinates','y x'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'location','node'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'mesh','adcirc_mesh'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'units','s'))
      endif
   case('minpr.63') ! minimum barometric pressure
      thisVarName = 'pressure_min'
      call initMinMaxFileMetaData(fn, thisVarName, .false.)
      call check(nf90_def_var(fn%nc_id,'pressure_min',nf90_double,n%nc_dimid_node,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','minimum air pressure at sea level'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','minimum_air_pressure_at_sea_level'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','meters of water'))
      if ( fn%timeOfOccurrence.eqv..true.) then
         call check(nf90_def_var(fn%nc_id,'time_of_pressure_min',nf90_double,n%nc_dimid_node,fn%ncds(2)%nc_varID))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'_fillValue',-99999.d0))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'long_name','time of minimum air pressure at sea level'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'standard_name','time_of_minimum_air_pressure_at_sea_level'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'coordinates','y x'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'location','node'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'mesh','adcirc_mesh'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'units','s'))
      endif
   case('maxvel.63') ! max water current velocity
      thisVarName = 'vel_max'
      call initMinMaxFileMetaData(fn, thisVarName, .false.)
      call check(nf90_def_var(fn%nc_id,'vel_max',nf90_double,n%nc_dimid_node,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','maximum water column vertically averaged velocity'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name','maximum_water column_vertically_averaged_velocity'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','m s-1'))
      if (fn%timeOfOccurrence.eqv..true.) then
         call check(nf90_def_var(fn%nc_id,'time_of_vel_max',nf90_double,n%nc_dimid_node,fn%ncds(2)%nc_varID))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'_fillValue',-99999.d0))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'long_name','time of maximum water column vertically averaged velocity'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'standard_name','time_of_maximum_water_column_vertically_averaged_velocity'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'coordinates','y x'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'location','node'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'mesh','adcirc_mesh'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'units','s'))
      endif
   case('swan_hs_max.63') ! swan_hs_max
      thisVarName = 'swan_hs_max'
      call initMinMaxFileMetaData(fn, thisVarName, .false.)
      call check(nf90_def_var(fn%nc_id,'swan_hs_max',nf90_double,nc_dimid,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','maximum significant wave height'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name', &
          'maximum_sea_surface_wave_significant_height'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','m'))
      if (fn%timeOfOccurrence.eqv..true.) then
         call check(nf90_def_var(fn%nc_id,'time_of_swan_hs_max',nf90_double,n%nc_dimid_node,fn%ncds(2)%nc_varID))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'_fillValue',-99999.d0))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'long_name','time of maximum significant wave height'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'standard_name', &
             'time_of_maximum_sea_surface_wave_significant_height'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'coordinates','y x'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'location','node'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'mesh','adcirc_mesh'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'units','s'))
      endif
   case('swan_tps_max.63') ! swan_tps_max
      thisVarName = 'swan_tps_max'
      call initMinMaxFileMetaData(fn, thisVarName, .false.)
      call check(nf90_def_var(fn%nc_id,'swan_tps_max',nf90_double,n%nc_dimid_node,fn%ncds(1)%nc_varID))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'_fillValue',-99999.d0))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'long_name','maximum smoothed peak period'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'standard_name', &
         'maximum_sea_surface_wave_period_at_variance_spectral_density_maximum'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'coordinates','time y x'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'location','node'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'mesh','adcirc_mesh'))
      call check(nf90_put_att(fn%nc_id,fn%ncds(1)%nc_varID,'units','s'))
      if ( fn%timeOfOccurrence.eqv..true.) then
         call check(nf90_def_var(fn%nc_id,'swan_tps_max',nf90_double,n%nc_dimid_node,fn%ncds(2)%nc_varID))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'_fillValue',-99999.d0))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'long_name','time of maximum smoothed peak period'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'standard_name', &
            'time_of_maximum_sea_surface_wave_period_at_variance_spectral_density_maximum'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'coordinates','y x'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'location','node'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'mesh','adcirc_mesh'))
         call check(nf90_put_att(fn%nc_id,fn%ncds(2)%nc_varID,'units','s'))
      endif
   case default
      call allMessage(ERROR,'Min/max file type not recognized.')
      stop
   end select
case default
   write(6,'(a)') 'ERROR: Unable to convert '//trim(fn%defaultFileName)//' files.'
end select
!
! set the number of values per dataset
if ( fn % dataFileCategory .eq. STATION ) then
   do i=1, fn%numVarNetCDF
      fn%ncds(i)%numValuesPerDataSet = fn%nStations
      nc_dimid = (/ fn%nc_dimid_station, fn%nc_dimID_Time /)
   end do
else
   do i=1, fn%numVarNetCDF
      fn%ncds(i)%numValuesPerDataSet = m%np ! general case
      nc_dimid = (/ n%nc_dimid_node, fn%nc_dimID_Time /)
      if (fn%ncds(i)%isElemental) then
         nc_dimid = (/ n%nc_dimid_nele, fn%nc_dimID_Time /)
         fn%ncds(i)%numValuesPerDataSet = m%ne
      endif
   end do
endif
!
write(6,*) 'INFO: Finished adding data attributes to netCDF file.'
!----------------------------------------------------------------------
end subroutine addDataAttributesNetCDF
!----------------------------------------------------------------------

!----------------------------------------------------------------------
!    S U B R O U T I N E   F O R M   M A X   F I L E   N A M E
!----------------------------------------------------------------------
! jgf: Form the name of the max (or min) file, given the name of the
! data file from which it will be derived.
!----------------------------------------------------------------------
subroutine formMaxFileName(datafile, maxFileName)
implicit none
character(len=1024), intent(in) :: datafile
character(len=1024), intent(out) :: maxFileName
character(len=1024) :: fileNameBase
integer :: extIndex
!
! defaults
fileNameBase = datafile
!
! find and trim off the extension, if any
extIndex = 0
extIndex = index(datafile,'.nc')
if (extIndex.ne.0) then
   fileNameBase = datafile(:extIndex-1)
endif
!
! pick the corresponding max file name
select case(trim(adjustl(fileNameBase)))
   case("fort.63")
      maxFileName = 'maxele.63'
   case("fort.64")
      maxFileName = 'maxvel.63'
   case("fort.73")
      maxFileName = 'minpr.63'
   case("fort.74")
      maxFileName = 'maxwvel.63'
   case("swan_DIR.63")
      maxFileName = 'swan_DIR_max.63'
   case("swan_HS.63")
      maxFileName = 'swan_HS_max.63'
   case("swan_TMM10.63")
      maxFileName = 'swan_TMM10_max.63'
   case("swan_TPS.63")
      maxFileName = 'swan_TPS_max.63'
   case default
      write(6,'(a,a,a)') 'WARNING: File name ',trim(adjustl(datafile)),' was not recognized.'
      maxFileName = trim(adjustl(fileNameBase)) // '_maxfile.63'
end select
write(6,'(a,a,a)') 'INFO: The max file name is set to ',trim(adjustl(maxFileName)),'.'
!----------------------------------------------------------------------
end subroutine formMaxFileName
!----------------------------------------------------------------------

!----------------------------------------------------------------------
!  S U B R O U T I N E     I N I T   F I L E   M E T A  D A T A
!----------------------------------------------------------------------
! Allocate memory to hold variable names, variable IDs, etc for
! variables in the targetted NetCDF4 files so the metadata can be
! appropriately written to the XDMF XML. Also initialize the newly
! allocated variables to reasonable values.
!----------------------------------------------------------------------
subroutine initFileMetaData(fmd, firstVarName, numNC, numXDMF)
use netcdf
implicit none
type(fileMetaData_t), intent(inout) :: fmd
character(NF90_MAX_NAME), intent(in) :: firstVarName
integer, intent(in) :: numNC
integer, intent(in) :: numXDMF
integer :: n
!
if ( fmd % initialized .eqv..true. ) then
   return
endif
allocate(fmd%ncds(numNC))
!
! NetCDF
fmd % numVarNetCDF = numNC
do n=1, numNC
   fmd % ncds(n) % varNameNetCDF = 'error: not_set'
   fmd % ncds(n) % nc_varID = -999
   fmd % ncds(n) % nc_varType = -999
   !fmd % ncds(n) % nc_varAttType = -999 ! commented out b/c unknown number of var atts
   !fmd % ncds(n) % nc_varAttName = 'error: not_set'
   fmd % ncds(n) % numValuesPerDataSet = -99
   fmd % ncds(n) % isElemental = .false.
   fmd % ncds(n) % isInteger = .false.
   fmd % ncds(n) % is3D = .false.
end do
!
! XDMF
fmd % numVarXDMF = numXDMF
allocate(fmd%xds(numXDMF))
!allocate(fmd%xds(2))
do n=1,fmd%numVarXDMF
   fmd % xds(n) % varNameXDMF = 'error: not_set'
   fmd % xds(n) % numComponents = 1    ! initialize to most common value
   fmd % xds(n) % dataCenter = 'Node'  ! initialize to most common value
   fmd % xds(n) % numberType = 'Float' ! initialize to most common value
   fmd % xds(n) % numberPrecision = 8  ! initialize to most common value
end do
fmd % ncds(1) % nc_varType = NF90_DOUBLE ! initialize to most common value
fmd % ncds(1) % varNameNetCDF = trim(firstVarName) ! initialize to most common value
fmd % xds(1) % varNameXDMF = trim(firstVarName) ! initialize to most common value
fmd % initialized = .true.
!----------------------------------------------------------------------
end subroutine initFileMetaData
!----------------------------------------------------------------------

!----------------------------------------------------------------------
! S U B R O U T I N E   I N I T  M I N  M A X  F I L E  M E T A D A T A
!----------------------------------------------------------------------
! Checks for the existence of time of occurrence data in the min max
! file before initializing the file metadata.
!----------------------------------------------------------------------
subroutine initMinMaxFileMetaData(fmd, someVarName, checkTimeOfOccurrence)
use netcdf
use logging, only : allMessage, INFO
use ioutil, only : check
implicit none
type(fileMetaData_t), intent(inout) :: fmd
character(NF90_MAX_NAME), intent(in) :: someVarName
logical, intent(in) :: checkTimeOfOccurrence ! true if unknown whether file contains time of occurrence data
!
character(NF90_MAX_NAME) timeOfVarName
character(NF90_MAX_NAME) aVarName
integer :: j
!
if ( fmd % initialized .eqv..true. ) then
   return
endif
!
timeOfVarName = 'time_of_'//trim(someVarName)
if (trim(someVarName).eq."inun_time") then
   timeOfVarName = 'last_'//trim(someVarName)
endif
if ( checkTimeOfOccurrence.eqv..true. ) then
   do j=1,fmd%nvar
      call check(nf90_inquire_variable(fmd%nc_id, j, aVarName))
      if (trim(aVarName).eq.trim(timeOfVarName)) then
         call allMessage(INFO,'The file contains time of occurrence data.')
         fmd % timeOfOccurrence = .true.
         exit
      endif
   end do
endif
if (fmd % timeOfOccurrence.eqv..true.) then
   call initFileMetaData(fmd, someVarName, 2, 2)
   fmd % ncds(2) % varNameNetCDF = trim(timeOfVarName)
   fmd % xds(2) % varNameXDMF = trim(timeOfVarName)
   fmd % timeOfOccurrence = .true. ! was reset in initFileMetaData
else
   call initFileMetaData(fmd, someVarName, 1, 1)
endif
fmd % timeVarying = .false. ! was reset in initFileMetaData
!----------------------------------------------------------------------
end subroutine initMinMaxFileMetaData
!----------------------------------------------------------------------

!----------------------------------------------------------------------
! S U B R O U T I N E   R E A D   O N E   D A T A S E T
!----------------------------------------------------------------------
! Reads one dataset from the file.
!----------------------------------------------------------------------
subroutine readOneDataSet(f, m, s, l, snapr, snapi)
use logging
use ioutil
use adcmesh
implicit none
type(fileMetaData_t), intent(inout) :: f  ! file to read data from
type(mesh_t), intent(inout) :: m ! mesh data structure associated with data
integer, intent(in) :: s      ! dataset number to read
integer, intent(inout) :: l  ! line number in ascii file
real(8), intent(out) :: snapr ! time (s) associated with the data
integer, intent(out) :: snapi ! time step number associated with the data
integer :: numNodesNonDefault ! for sparse ascii datasets
real(8) :: dtemp(3) ! temporary holder for multicomponent data at a location
integer :: h ! horizontal node counter
integer :: n ! horizontal node counter
integer :: c ! component counter
integer :: v ! vertical node counter
integer :: itemp
integer :: nc_start(2)
integer :: nc_count(2)
integer :: nc_start3D(3)
integer :: nc_count3D(3)
integer :: errorIO ! i/o error flag
character(len=10000) :: line ! used in debugging
!
if ( (f%dataFileFormat.eq.NETCDFG).and.(s.gt.f%nSnaps) ) then
   call allMessage(INFO,'All datasets have been read.')
   return
endif
!
select case(f%dataFileFormat)
case(ASCII,ASCIIG)
   !
   ! READ 3D ASCII DATASET HEADER
   !
   ! assumes there are no sparse integer datasets, 3D integer datasets,
   ! or 3D sparse datasets
   if (f%is3D.eqv..true.) then
      select case(f%irtype)
      case(1)
         read(f%fun,end=246,err=248,fmt=*) snapr, snapi, (m%sigma(v),v=1,m%nfen-1)
      case(2)
         read(f%fun,end=246,err=248,fmt=*) snapr, snapi, (m%sigma(v),m%sigma(v),v=1,m%nfen-1),m%sigma(m%nfen)
      case(3)
         read(f%fun,end=246,err=248,fmt=*) snapr, snapi, (m%sigma(v),m%sigma(v),m%sigma(v),v=1,m%nfen-1),m%sigma(m%nfen),m%sigma(m%nfen)
      case default
         call allMessage(ERROR,'Cannot convert 3D data with more than 3 components.')
         stop
      end select
      l = l + 1
   else
      !
      ! READ 2DDI ASCII DATASET HEADER
      !
      ! sparse
      if (f%isSparse) then
         read(f%fun,fmt=*,end=246,err=248,iostat=errorio) snapr, snapi, numNodesNonDefault, f%defaultValue
         l = l + 1
      else
         ! non-sparse and non-fort.88
         if (f%dataFileCategory.ne.INITRIVER) then

                  ! jgfdebug
         !read(unit=f%fun,fmt=*,end=246,err=248,iostat=errorio) line
         !write(*,*) trim(adjustl(line))

            read(f%fun,fmt=*,end=246,err=248,iostat=errorio) SnapR, SnapI
            numNodesNonDefault = f%numValuesPerDataSet
            l = l + 1
         endif
      endif
   endif
   !
   ! READ ONE ASCII DATASET
   if (f%is3D.eqv..true.) then
      do h=1,f%numValuesPerDataSet
         read(unit=f%fun,fmt=*,end=246,err=248,iostat=errorio) n, ((f%rdata3D(c,h,v),c=1,f%irtype),v=1,m%nfen)
         l = l + 1
      end do
   endif
   if (f%isSparse.eqv..true.) then
      f%rdata = f%defaultValue
   endif
   if (f%isInteger.eqv..true.) then
      do n=1,numNodesNonDefault
         read(unit=f%fun,fmt=*,end=246,err=248,iostat=errorio) h, itemp
         l = l + 1
         f%idata(1,h) = itemp
      end do
   else
      ! sparse or full ascii real numbers
      do n=1,numNodesNonDefault

         ! jgfdebug
         !read(unit=f%fun,fmt=*,end=246,err=248,iostat=errorio) line
         !write(*,*) trim(adjustl(line))

         read(unit=f%fun,fmt=*,end=246,err=248,iostat=errorio) h, (dtemp(c), c=1,f%irtype)
         l = l + 1
         !if (allocated(f%rdata).eqv..true.) then
         !   write(6,*) allocated(f%rdata),'allocated' ! jgfdebug
         !else
         !   write(6,*) allocated(f%rdata),'not allocated'! jgfdebug
         !endif
         f%rdata(1:f%irtype,h) = dtemp(1:f%irtype)
      end do
   endif
case(NETCDFG,NETCDF3,NETCDF4)
   snapr = f%timesec(s)
   do c=1,f%numVarNetCDF
      ! read single dataset from netcdf
      if (m%is3D.eqv..true.) then
         ! read 3D data set
         nc_start3D = (/ 1, 1, s /)
         nc_count3D = (/ f%ncds(c)%numValuesPerDataSet, m%nfen, 1 /)
         call check(nf90_get_var(f%nc_id,f%ncds(c)%nc_varID,f%ncds(c)%rdata3D,nc_start3D,nc_count3D))
      else
         ! read 2D data set
         nc_start = (/ 1, s /)
         nc_count = (/ f%ncds(c)%numValuesPerDataSet, 1 /)
         if (f%ncds(c)%isInteger.eqv..true.) then
            call check(nf90_get_var(f%nc_id,f%ncds(c)%nc_varID,f%ncds(c)%idata,nc_start,nc_count))
         else
            call check(nf90_get_var(f%nc_id,f%ncds(c)%nc_varID,f%ncds(c)%rdata,nc_start,nc_count))
         endif
      endif
   end do
case default
   call allMessage(ERROR,'Only ASCII and NetCDF fulldoman file formats are supported.')
   stop
end select
!
if (allocated(f%it).eqv..true.) then
   snapi = f%it(s)
else
   snapi = -99
endif
!
if (f%dataFileCategory.eq.INITRIVER) then
   l = -99 ! fort.88 files always contain only a single dataset
endif
!
return
!
! We jump to this section if there are no more datasets to read
246  l = -99  ! indicate to calling routine that the ascii file has ended
return

248  call allMessage(ERROR,'I/O error during file access.')     ! ERR jumps here
write(6,'(a,i0,a,i0,a)') 'INFO: Attempted to read line ',l,' in dataset ',s,'.'
write(6,'(a,i0,a)') 'The numerical code of the i/o error was ',errorio,'.'
stop
!----------------------------------------------------------------------
end subroutine readOneDataSet
!----------------------------------------------------------------------


subroutine writeOneDataSet(f, m, s, l, snapr, snapi)
use logging
use ioutil
use adcmesh
implicit none
type(fileMetaData_t), intent(in) :: f  ! file to write data to
type(mesh_t), intent(in) :: m ! mesh data structure associated with data
integer, intent(in) :: s      ! dataset number to write
integer, intent(in) :: l  ! line number in ascii file
real(8), intent(in) :: snapr ! time (s) associated with the data
integer, intent(in) :: snapi ! time step number associated with the data
integer :: numNodesNonDefault ! for sparse ascii datasets
integer :: c ! component counter
integer :: h ! horizontal node counter
integer :: n ! horizontal node counter
integer :: v ! vertical node counter
integer :: nc_start(2)
integer :: nc_count(2)
integer :: nc_start3D(3)
integer :: nc_count3D(3)
integer :: ncCountMinMax(1)
integer :: ncStartMinMax(1)
!
select case(f%dataFileFormat)
case(ASCII,SPARSE_ASCII,ASCIIG)

   !jgfdebug


   if (f%is3D.eqv..true.) then
      !
      ! WRITE 3D DATA
      !
      select case(f%irtype)
      case(1)
         write(f%fun,2121) snapr, snapi, (m%sigma(v),v=1,m%nfen-1)
      case(2)
         write(f%fun,2121) snapr, snapi, (m%sigma(v),m%sigma(v),v=1,m%nfen-1),m%sigma(m%nfen)
      case(3)
         write(f%fun,2121) snapr, snapi, (m%sigma(v),m%sigma(v),m%sigma(v),v=1,m%nfen-1),m%sigma(m%nfen),m%sigma(m%nfen)
      case default
         call allMessage(ERROR,'Cannot convert 3D data with more than 3 components.')
         stop
      end select
      ! write 3D dataset, depending on how it was stored
      if (allocated(f%rdata3D).eqv..true.) then ! came from ascii file
         do h=1,f%numValuesPerDataSet
            write(f%fun,2454) h,((f%rdata3D(c,h,v),c=1,f%irtype),v=1,m%nfen)
         end do
      else                     ! came from netcdf file
         do h=1,f%numValuesPerDataSet
            write(f%fun,2454) h,((f%ncds(c)%rdata3D(h,v),c=1,f%irtype),v=1,m%nfen)
         end do
      endif
   else
      !
      !  2D INTEGER DATA
      !
      if ( f%isInteger.eqv..true.) then
         ! write integer dataset header
         write(f%fun,2120) snapr, snapi
         ! write integer dataset
         if (allocated(f%idata).eqv..true.) then
            do h=1,f%numValuesPerDataSet  ! came from ascii file
               write(f%fun,2452) h, (f%idata(c,h), c=1,f%irtype)
            end do
         else
            do h=1,f%numValuesPerDataSet  ! came from ascii file
               write(f%fun,2452) h, (f%ncds(c)%idata(h), c=1,f%irtype)
            end do
         endif
      else
         !
         !  2D SPARSE REAL DATA
         !
         if ( f%isSparse.eqv..true.) then
            numNodesNonDefault = count(f%rdata(1,:).ne.f%defaultValue)
            ! write sparse dataset header
            write(f%fun,2119) snapr, snapi, numNodesNonDefault, f%defaultValue
            ! write sparse dataset
            n=1
            if (allocated(f%rdata).eqv..true.) then ! came from ascii
               do h=1,f%numValuesPerDataSet
                  if ( f%rdata(1,h).ne.f%defaultValue) then
                     write(f%fun,2453) n, f%rdata(1,h)
                  endif
                  n=n+1
               end do
            else
               do h=1,f%numValuesPerDataSet            ! came from netcdf
                  if ( f%ncds(1)%rdata(h).ne.f%defaultValue) then
                     write(f%fun,2453) n, f%ncds(1)%rdata(h)
                  endif
                  n=n+1
               end do
            endif
         else
         !
         ! 2D FULL REAL DATA
         !
            write(f%fun,2120) snapr, snapi
            ! write full dataset
            !jgfdebug
            !write(*,*) f%numValuesPerDataset
            if (allocated(f%rdata).eqv..true.) then
               do h=1,f%numValuesPerDataset       ! came from ascii
                  write(f%fun,2453) h, (f%rdata(c,h), c=1,f%irtype)
               end do
            else
               do h=1,f%numValuesPerDataset       ! came from netcdf
                  write(f%fun,2453) h, (f%ncds(c)%rdata(h), c=1,f%irtype)
               end do
            endif
            ! write minmax time of occurrence if necessary
            !if ( (f%dataFileCategory.eq.MINMAX).and.(f%timeOfOccurrence.eqv..true.) ) then
            !   do h=1,f%numValuesPerDataset
            !      write(f%fun,2453) h, (f%rdata(c,h), c=1,f%irtype)
            !   end do
            !  !exit
            !endif
         endif
      endif
   endif
case(NETCDFG,NETCDF3,NETCDF4)
   if ( f%dataFileCategory.ne.MINMAX ) then
      if ( f%defaultFileName.ne.'ESLNodes.63') then
         call check(nf90_put_var(f%nc_id, f%nc_varid_time, (/snapr/), (/s/), (/1/)))
      endif
   endif
   if (allocated(f%it).eqv..true.) then
      call check(nf90_put_var(f%nc_id, f%nc_varid_it, (/snapi/), (/s/), (/1/)))
   endif
   NC_Count = (/ f%numValuesPerDataset, 1 /)
   NC_Start = (/ 1, s /)
   !
   ncStartMinMax = (/ 1 /)
   ncCountMinMax = (/ s /)
   ! write the dataset to the netcdf file
   do c=1,f%numVarNetCDF
      if (m%is3D.eqv..true.) then
         ! write 3D data set
         nc_start3D = (/ 1, 1, s /)
         nc_count3D = (/ f%ncds(c)%numValuesPerDataSet, m%nfen, 1 /)
         if (allocated(f%ncds(c)%rdata3D).eqv..true.) then
            ! data came from netcdf
            call check(nf90_put_var(f%nc_id,f%ncds(c)%nc_varID,f%ncds(c)%rdata3D,nc_start3D,nc_count3D))
         else
            ! data came from ascii file
            call check(nf90_put_var(f%nc_id,f%ncds(c)%nc_varID,f%rdata3D(c,:,:),nc_start3D,nc_count3D))
         endif
      else
         ! integer data
         if (f%ncds(1)%isInteger.eqv..true.) then
            if (allocated(f%ncds(c)%idata).eqv..true.) then
               ! data came from netcdf
               call check(nf90_put_var(f%nc_id,f%ncds(c)%nc_varID,f%ncds(c)%idata,nc_start,nc_count))
            else
               ! data came from ascii
               call check(nf90_put_var(f%nc_id,f%ncds(c)%nc_varID,f%idata(c,:),nc_start,nc_count))
            endif
         else
            ! real data
            if (allocated(f%ncds(c)%rdata).eqv..true.) then
               ! data came from netcdf
               call check(nf90_put_var(f%nc_id,f%ncds(c)%nc_varID,f%ncds(c)%rdata,nc_start,nc_count))
            else
               ! data came from ascii
               if ((f%dataFileCategory.eq.MINMAX).and.(f%timeOfOccurrence.eqv..true.).and.(s.eq.2)) then
                  call check(nf90_put_var(f%nc_id,f%ncds(2)%nc_varID,f%rdata(c,:),nc_start,nc_count))
               else if (f%defaultFileName.eq.'ESLNodes.63') then
                  call check(nf90_put_var(f%nc_id,f%ncds(c)%nc_varID,f%rdata(c,:),(/ 1 /), (/ 1 /)))
               else
                  call check(nf90_put_var(f%nc_id,f%ncds(c)%nc_varID,f%rdata(c,:),nc_start,nc_count))
               endif
            endif
         endif
      endif
   end do
case default
   ! should be unreachable
   call allMessage(ERROR,'Only ASCII or NETCDF result file formats are supported.')
   stop
end select

 2119 FORMAT(2X,1pE20.10E3,5X,i0,5x,i0,5x,1pE20.10E3)
 2120 format(2x,1pe20.10e3,5x,i10)
 2121 format(2x,1pe20.10e3,5x,i10,99(1pe20.10e3,2x))
 2452 format(2x, i8, 2x, i0, 5x, i0, 5x, i0, 5x, i0)
 2453 format(2x, i8, 2x, 1pe20.10e3, 1pe20.10e3, 1pe20.10e3, 1pe20.10e3)
 2454 format(2x, i8, 2x, 99(1pe20.10e3))

end subroutine writeOneDataSet







!----------------------------------------------------------------------
!                S U B R O U T I N E
!     L O A D   N E T C D F   M E T A D A T A
!         F R O M   E X T E R N A L   F I L E
!----------------------------------------------------------------------
! Load netCDF Attributes if they have been provided by an external file
! or fill in dummy files if no external file was provided
!----------------------------------------------------------------------

subroutine loadNetCDFMetadataFromExternalFile(a)
use ioutil
use logging
implicit none
type (netCDFMetaDataFromExternalFile_t) :: a
integer :: errorIO
integer :: i
!
if (trim(a%nmattFileName).eq.'null') then
   ! set default netcdf metadata in case they were not provided
   call allMessage(INFO,'Setting default netcdf metadata/attributes.')
   a%nmatt = 10
   allocate(a%matt(1:2,1:a%nmatt))
   a%datenum = 'seconds since 2008-07-31 12:00:00 +00:00'
   a%matt(1:2,1) = 'NCPROJ'
   a%matt(1:2,2) = 'NCINST'
   a%matt(1:2,3) = 'NCSOUR'
   a%matt(1:2,4) = 'NCHIST'
   a%matt(1:2,5) = 'NCREF'
   a%matt(1:2,6) = 'NCCOM'
   a%matt(1:2,7) = 'NCHOST'
   a%matt(1:2,8) = 'NCCONV'
   a%matt(1:2,9) = 'NCCONT'
   a%matt(1:2,10) = 'NCDATE'
   a%lineNum=1
else
   call allMessage(INFO,'Opening netcdf metadata/attributes file.')
   a%nmUnit = availableUnitNumber()
   call openFileForRead(a%nmUnit,a%nmattFileName,errorIO)
   read(a%nmUnit,*,end=246,err=248,iostat=errorio) a%nmatt
   a%lineNum = a%lineNum + 1
   allocate(a%matt(1:2,1:a%nmatt))
   read(a%nmUnit,'(A)',end=246,err=248,iostat=errorio) a%datenum !seconds since 2008-07-31 12:00:00 +00:00
   a%lineNum = a%lineNum + 1
   do i = 1,a%nmatt
      read(a%nmUnit,*,end=246,err=248,iostat=errorio) a%matt(1,i), a%matt(2,i)
      a%lineNum = a%lineNum + 1
   enddo
   close(a%nmUnit)
   write(6,'(a)') "INFO: Finished reading metadata/attributes file."
endif
return
      ! We jump to this section if there was an error reading a file.
246   write(6,'(a)') 'ERROR: Unexpectedly reached end-of-file.' ! END jumps here
248   write(6,'(a)') 'ERROR: I/O error during file access.'     ! ERR jumps here
write(6,'(a,i0,a,i0,a)') 'Attempted to read line ',a%lineNum,'.' ! ERR jumps here
write(6,'(a,i0,a)') 'The numerical code of the i/o error was ',errorio,'.'

!----------------------------------------------------------------------
end subroutine loadNetCDFMetadataFromExternalFile
!----------------------------------------------------------------------

!-----------------------------------------------------------------------
!  S U B R O U T I N E   C H E C K  E R R  O W I
!-----------------------------------------------------------------------
! Checks the return value from subroutine calls; if there
! was an error, it writes a termination message and exits.
!-----------------------------------------------------------------------
subroutine checkErrOWI(iret,errorVar,defaultFileName)
use logging
implicit none
integer, intent(in) :: iret
character(len=2048), intent(in) :: errorVar
character(len=20), intent(in) :: defaultFileName

if (iret.ne.0) then
   if (trim(errorVar).ne."") then
      write(scratchMessage,'("Failed to read ",a," from ",a,".")') trim(errorVar), trim(defaultFileName)
      call allMessage(ERROR,scratchMessage)
   else
      write(scratchMessage,'("Failed to read ",a,".")') trim(defaultFileName)
      call allMessage(ERROR,scratchMessage)
      stop
   endif
endif
!-----------------------------------------------------------------------
end subroutine checkErrOWI
!-----------------------------------------------------------------------

!-----------------------------------------------------------------------
! Initialize a 1D vector of real numbers
!-----------------------------------------------------------------------
subroutine initR1D(vec)
implicit none
type(realVector1D_t), intent(inout) :: vec
vec%n = 0
vec%ninc = 100
vec%s = vec%ninc
allocate(vec%v(0:vec%s+1))
!-----------------------------------------------------------------------
end subroutine initR1D
!-----------------------------------------------------------------------

!-----------------------------------------------------------------------
! Append a real number to a 1D vector of real numbers.
!-----------------------------------------------------------------------
subroutine appendR1D(vec, rval)
implicit none
type(realVector1D_t), intent(inout) :: vec
real(8), intent(in) :: rval
! allocate more memory if necessary
if (vec%n.eq.vec%s) then
   ! create temp variable
   allocate(vec%vtemp(vec%n))
   ! copy array values to temp space
   vec%vtemp(1:vec%n) = vec%v(1:vec%n)
   deallocate(vec%v)
   ! increase size of array by the given increment
   vec%s = vec%n + vec%ninc
   allocate(vec%v(vec%s))
   ! copy the values back from the temp array
   vec%v(1:vec%n) = vec%vtemp(1:vec%n)
   deallocate(vec%vtemp)
endif
vec%v(vec%n+1) = rval
vec%n = vec%n + 1
!-----------------------------------------------------------------------
end subroutine appendR1D
!-----------------------------------------------------------------------

!-----------------------------------------------------------------------
! Initialize a 1D vector of integers.
!-----------------------------------------------------------------------
subroutine initI1D(vec)
implicit none
type(integerVector1D_t), intent(inout) :: vec
vec%n = 0
vec%ninc = 100
vec%s = vec%ninc
allocate(vec%v(0:vec%s+1))
!-----------------------------------------------------------------------
end subroutine initI1D
!-----------------------------------------------------------------------

!-----------------------------------------------------------------------
! Append an integer to a 1D vector of integers.
!-----------------------------------------------------------------------
subroutine appendI1D(vec, ival)
implicit none
type(integerVector1D_t), intent(inout) :: vec
integer, intent(in) :: ival
! allocate more memory if necessary
if (vec%n.eq.vec%s) then
   ! create temp variable
   allocate(vec%vtemp(vec%n))
   ! copy array values to temp space
   vec%vtemp(1:vec%n) = vec%v(1:vec%n)
   deallocate(vec%v)
   ! increase size of array by the given increment
   vec%s = vec%n + vec%ninc
   allocate(vec%v(vec%s))
   ! copy the values back from the temp array
   vec%v(1:vec%n) = vec%vtemp(1:vec%n)
   deallocate(vec%vtemp)
endif
vec%v(vec%n+1) = ival
vec%n = vec%n + 1
!-----------------------------------------------------------------------
end subroutine appendI1D
!-----------------------------------------------------------------------


!-----------------------------------------------------------------------
! Initialize a 1D vector of character strings.
!-----------------------------------------------------------------------
subroutine initC1D(vec)
implicit none
type(characterVector1D_t), intent(inout) :: vec
vec%n = 0
vec%ninc = 100
vec%s = vec%ninc
allocate(vec%v(0:vec%s+1))
!-----------------------------------------------------------------------
end subroutine initC1D
!-----------------------------------------------------------------------

!-----------------------------------------------------------------------
! Append an integer to a 1D vector of character strings.
!-----------------------------------------------------------------------
subroutine appendC1D(vec, cstr)
implicit none
type(characterVector1D_t), intent(inout) :: vec
character(len=2000), intent(in) :: cstr
! allocate more memory if necessary
if (vec%n.eq.vec%s) then
   ! create temp variable
   allocate(vec%vtemp(vec%n))
   ! copy array values to temp space
   vec%vtemp(1:vec%n) = vec%v(1:vec%n)
   deallocate(vec%v)
   ! increase size of array by the given increment
   vec%s = vec%n + vec%ninc
   allocate(vec%v(vec%s))
   ! copy the values back from the temp array
   vec%v(1:vec%n) = vec%vtemp(1:vec%n)
   deallocate(vec%vtemp)
endif
vec%v(vec%n+1) = cstr
vec%n = vec%n + 1
!-----------------------------------------------------------------------
end subroutine appendC1D
!-----------------------------------------------------------------------


!-----------------------------------------------------------------------
! Call the right subroutine to close a file, taking into account the
! file type (ascii or netcdf).
!-----------------------------------------------------------------------
subroutine closeFile(f)
use ioutil
use logging
implicit none
type(fileMetaData_t), intent(inout) :: f
select case(f%dataFileFormat)
case(ASCII)
   close(f%fun)
case(NETCDFG)
   call check(nf90_close(f%nc_id))
case default
   ! should be unreachable
   call allMessage(ERROR,'Only ASCII or NETCDF result file formats are supported.')
   stop
end select
!-----------------------------------------------------------------------
end subroutine closeFile
!-----------------------------------------------------------------------

!----------------------------------------------------------------------
!----------------------------------------------------------------------
end module asgsio
!----------------------------------------------------------------------
!----------------------------------------------------------------------
