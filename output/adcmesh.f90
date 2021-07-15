!-----+---------+---------+---------+---------+---------+---------+
!
! adcmesh.f90
! This is a module for storing and manipulating data for ADCIRC meshes;
! it is based on code originally written by Corbitt Kerr.
!
!-----+---------+---------+---------+---------+---------+---------+
module adcmesh
!-----+---------+---------+---------+---------+---------+---------+
use netcdf, only : NF90_MAX_NAME
real(8), parameter :: R = 6378206.4d0 ! radius of the earth
real(8), parameter :: pi = 3.141592653589793d0
real(8), parameter :: deg2rad = pi/180.d0
real(8), parameter :: rad2deg = 180.d0/pi
real(8), parameter :: oneThird = 1.d0/3.d0
logical :: verbose

!
! elevation boundaries and flux boundaries where
! ibtype = 0,1,2,10,11,12,20,21,22,30,52
type simpleBoundary_t
   integer :: indexNum                ! order within the fort.14 file (used to get IBTYPE etc)
   integer :: informationID           ! xdmf ID for IBTYPEE or IBTYPE info
   integer :: setID                   ! xdmf ID for node numbers
   integer, allocatable :: nodes(:) ! node numbers on boundary
   real(8), allocatable :: bGeom(:)  ! coordinates for visualization
end type simpleBoundary_t
!
! flux boundaries where ibtype = 3, 13, 23
type externalFluxBoundary_t
   integer :: indexNum               ! order within the fort.14 file
   integer :: informationID              ! xdmf ID for IBTYPE info
   integer :: setID                      ! xdmf ID for node numbers
   integer :: numAttributes = 2
   integer :: attributeIDs(2) ! xdmf IDs for parameters
   integer, allocatable :: nodes(:)
   real(8), allocatable :: barlanht(:)
   real(8), allocatable :: barlancfsp(:)
   real(8), allocatable :: leveeGeom(:)
end type externalFluxBoundary_t
!
! flux boundaries where ibtype = 4, 24
type internalFluxBoundary_t
   integer :: indexNum               ! order within the fort.14 file
   integer :: informationID              ! xdmf ID for IBTYPE info
   integer :: setID                      ! xdmf ID for node numbers
   integer :: numAttributes = 4
   integer :: attributeIDs(4) ! xdmf IDs for parameters
   integer, allocatable :: nodes(:)
   integer, allocatable :: ibconn(:)
   real(8), allocatable :: barinht(:)
   real(8), allocatable :: barincfsb(:)
   real(8), allocatable :: barincfsp(:)
   real(8), allocatable :: leveeGeom(:)
   integer, allocatable :: ibTypeAttribute(:) ! used for visualization
end type internalFluxBoundary_t
!
! flux boundaries where ibtype = 5, 25
type internalFluxBoundaryWithPipes_t
   integer :: indexNum               ! order within the fort.14 file
   integer :: informationID              ! xdmf ID for IBTYPE info
   integer :: setID                      ! xdmf ID for node numbers
   integer :: numAttributes = 7
   integer :: attributeIDs(7) ! xdmf IDs for parameters
   integer, allocatable :: nodes(:)
   integer, allocatable :: ibconn(:)
   real(8), allocatable :: barinht(:)
   real(8), allocatable :: barincfsb(:)
   real(8), allocatable :: barincfsp(:)
   real(8), allocatable :: pipeht(:)
   real(8), allocatable :: pipecoef(:)
   real(8), allocatable :: pipediam(:)
   real(8), allocatable :: leveeGeom(:)
end type internalFluxBoundaryWithPipes_t
!
!
type mesh_t
   !
   character(NF90_MAX_NAME) :: meshFileName ! full pathname of file
   !
   real(8), allocatable :: xyd(:,:)
   real(8), allocatable :: bar(:,:,:)
   !
   ! parameters related to carte parallelogrammatique projection (CPP)
   logical :: cppComputed = .false.
   real(8), allocatable :: x_cpp(:)
   real(8), allocatable :: y_cpp(:)
   !
   ! parameters related to Albers Equal Area Conic projection
   logical :: albersComputed = .false.
   real(8), allocatable :: xalbers(:)
   real(8), allocatable :: yalbers(:)
   !
   ! parameters related to the neighbor edge length table (np,neimax)
   logical :: neighborEdgeLengthTableComputed = .false. ! .true. when mem is allocated for this
   real(8), allocatable :: neighborEdgeLengthTable(:,:)
   real(8) :: minEdgeLength ! shortest edge length in the whole mesh (m)
   real(8) :: maxEdgeLength ! longest edge length in the whole mesh (m)
   real(8), allocatable :: areas(:) ! (ne) 2x element areas in square meters
   real(8), allocatable :: eledepths(:) ! (ne) element bathymetric depths (m)
   real(8), allocatable :: sfac(:) ! (np)
   real(8), allocatable :: sfacAvg(:) ! (ne)
   real(8), allocatable :: fdx(:,:) ! (3,ne)
   real(8), allocatable :: fdy(:,:) ! (3,ne)
   real(8), allocatable :: centroids(:,:) ! (2,ne) x and y coordinates of the element centroids
   integer :: mnei = 15  ! maximum number of neighbors for a node
   !
   character(2048) :: agrid
   integer :: ne   ! number of elements
   integer :: np   ! number of nodes
   integer, allocatable :: nmnc(:,:) ! element table in netcdf (3,ne)
   integer, allocatable :: nm(:,:)   ! element table in adcirc (ne,3)
   integer :: nfen
   real(8), allocatable :: sigma(:)
   logical :: is3D  ! true if the mesh is 3D
   ! boundary related parameters
   logical :: readBoundaryTable = .true.
   integer :: neta_count ! count of open boundary nodes
   integer :: nvel_count ! count of land boundary nodes
   integer :: nope ! number of open (ocean) elevation specified boundaries
   integer :: neta ! total number of nodes on open (ocean) elevation specified boundary nodes
   integer :: nbou ! number of flux specified boundaries
   integer :: nvel ! total number of nodes on flux specified boundaries
   integer, allocatable :: nvdll(:)  ! number of nodes on each open boundary
   integer, allocatable :: nbdv(:,:) ! node numbers on each open boundary
   integer, allocatable :: nvell(:)  ! number of nodes on each flux boundary
   integer, allocatable :: ibtype(:) ! boundary type of each flux boundary
   integer, allocatable :: ibtypee(:) ! boundary type of each elevation boundary
   integer, allocatable :: nbvv(:,:) ! node numbers on each flux boundary
   integer, allocatable :: lbcodei(:) ! bound. type array for flux boundaries
   integer :: nvdll_max  ! longest elevation boundary
   integer :: nvell_max  ! longest flux boundary
   integer, allocatable :: nbd(:)
   integer, allocatable :: nbv(:)
   integer, allocatable :: ibconn(:,:)
   integer, allocatable :: ibtype_orig(:)
   integer, allocatable :: bcrnbvv(:,:)
   integer, allocatable :: bcrnvell(:)
   real(8), allocatable :: barlanht(:,:)
   real(8), allocatable :: barinht(:,:)
   real(8), allocatable :: pipeht(:,:)
   real(8), allocatable :: barlancfsp(:,:)
   real(8), allocatable :: barlancfsb(:,:)
   real(8), allocatable :: barincfsb(:,:)
   real(8), allocatable :: barincfsp(:,:)
   real(8), allocatable :: pipediam(:,:)
   real(8), allocatable :: pipecoef(:,:)

   logical :: elementAreasComputed = .false.
   logical :: elementDepthsComputed = .false.
   logical :: weightingCoefficientsComputed = .false.
   logical :: neighborTableComputed = .false.
   logical :: allLeveesOK ! .false. if there are any issues
   integer :: NEIMIN
   integer :: NEIMAX
   integer, allocatable :: NNeigh(:)
   integer, allocatable :: NeiTab(:,:)
   integer, allocatable :: NeiTabGenerated(:,:)
   integer, allocatable :: NeiTabEle(:,:)
   integer, allocatable :: NeiTabEleGenerated(:,:)
   integer, allocatable :: nneighele(:)
   real(8) :: slam0  ! longitude on which cpp projection is centered (degrees)
   real(8) :: sfea0  ! latitude on which cpp projection is centered (degrees)
   real(8) :: lonmin   ! domain extents (degrees)
   real(8) :: lonmax
   real(8) :: latmin
   real(8) :: latmax
   !
   ! elevation boundaries
   type(simpleBoundary_t), allocatable :: elevationBoundaries(:)
   integer :: numElevationBoundaries ! for memory allocation
   !
   ! mainland and island boundaries
   type(simpleBoundary_t), allocatable :: simpleFluxBoundaries(:)
   integer :: numSimpleFluxBoundaries ! for memory allocation
   ! variable holding flux boundaries with ibtype = 0, 1, 2, 10, 11, 12, 20, 21, 22, 30, 52
   integer :: sfCount   ! index into the simpleFluxBoundaries array
   !
   ! external overflow boundary and river boundary
   type(externalFluxBoundary_t), allocatable :: externalFluxBoundaries(:)
   integer :: numExternalFluxBoundaries
   integer :: efCount   ! index into the externalFluxBoundaries array
   !
   ! levee boundaries
   type(internalFluxBoundary_t), allocatable :: internalFluxBoundaries(:)
   integer :: numInternalFluxBoundaries
   integer :: ifCount   ! index into the internalFluxBoundaries array
   !
   ! levees with cross barrier pipes
   type(internalFluxBoundaryWithPipes_t), allocatable :: internalFluxBoundariesWithPipes(:)
   integer :: numInternalFluxBoundariesWithPipes
   integer :: ifwpCount ! index into the internalFluxBoundariesWithPipes array

   integer :: nfluxf ! =1 if there are any specified flux boundaries in the mesh

end type mesh_t

type meshNetCDF_t
   integer :: NC_DimID_node = -99
   integer :: NC_DimID_nfen = -99
   integer :: NC_DimID_nele = -99
   integer :: NC_DimID_nvertex = -99
   integer :: NC_DimID_nope = -99
   integer :: NC_DimID_max_nvdll = -99
   integer :: NC_DimID_nbou = -99
   integer :: NC_DimID_neta = -99
   integer :: NC_DimID_nvel = -99
   integer :: NC_DimID_max_nvell = -99
   integer :: NC_VarID_Mesh = -99
   integer :: NC_VarID_x = -99
   integer :: NC_VarID_y = -99
   integer :: NC_VarID_sigma = -99
   integer :: NC_VarID_nfen = -99
   integer :: NC_VarID_element = -99
   integer :: NC_VarID_neta = -99
   integer :: NC_VarID_nvdll = -99
   integer :: NC_VarID_max_nvdll = -99
   integer :: NC_VarID_ibtypee = -99
   integer :: NC_VarID_nbdv = -99
   integer :: NC_VarID_nvel = -99
   integer :: NC_VarID_nope  = -99
   integer :: NC_VarID_nvell = -99
   integer :: NC_VarID_max_nvell = -99
   integer :: NC_VarID_ibtype = -99
   integer :: NC_VarID_nbvv = -99
   integer :: NC_VarID_depth = -99
   integer :: NC_VarID_x_cpp = -99
   integer :: NC_VarID_y_cpp = -99
end type meshNetCDF_t

integer, parameter :: specifiedFluxBoundaryTypes(5) = (/ 2, 12, 22, 32, 52 /)
!
! all info needed for self describing dataset in XDMF
type xdmfMetaData_t
   logical :: createdIDs        ! .true. if infoIDs have been created
   character(80) :: variable_name
   integer :: variable_name_id
   character(80) :: long_name
   integer :: long_name_id
   character(80) :: standard_name
   integer :: standard_name_id
   character(80) :: coordinates
   integer :: coordinates_id
   character(80) :: units
   integer :: units_id
   character(80) :: positive
   integer :: positive_id
   integer :: ndset ! number of data sets
end type xdmfMetaData_t
!
! info related to recording stations
type station_t
   real(8) :: lon            ! decimal degrees east
   real(8) :: lat            ! decimal degrees north
   real(8) :: z              ! vertical position (m) relative to mesh zero
   integer :: irtype         ! number of components; 1=scalar, 2=2D vector, 3=3D vector
   logical :: elementFound   ! true if the element number is known
   integer :: elementIndex   ! where station is located in a particular mesh element table array
   real(8) :: elementArea    ! total area in m^2
   real(8) :: elementBathyDepth       ! spatially weighted interpolation of nodal depths (m)
   integer :: n(3)           ! nodes that surround the station
   real(8) :: w(3)           ! weights used to interpolate station values based on nodal values
   real(8), allocatable :: d(:,:)     ! station data (irtype, ntime)
   integer :: iID            ! simple numerical ID
   character(len=1024) :: stationID   ! generally a number assigned by govt agency
   character(len=1024) :: description ! human readable
   character(len=1024) :: agency      ! organization responsible for the station
   character(len=1024) :: datum       ! relevant vertical datum (MSL, NAVD88, etc)
end type station_t

!-----+---------+---------+---------+---------+---------+---------+
contains
!-----+---------+---------+---------+---------+---------+---------+

!-----+---------+---------+---------+---------+---------+---------+
!  READ14_FindDims
!-----+---------+---------+---------+---------+---------+---------+
subroutine read14_findDims(m)
use ioutil
implicit none
type(mesh_t), intent(inout) :: m ! mesh to operate on
integer :: ios ! i/o status
integer :: lineNum ! line number currently being read
integer :: i, j, k
integer :: iunit
integer :: errorIO

! initializations
lineNum = 1
m%numSimpleFluxBoundaries = 0
m%numExternalFluxBoundaries = 0
m%numInternalFluxBoundaries = 0
m%numInternalFluxBoundariesWithPipes = 0
m%is3D = .false.
!
iunit = availableUnitNumber()
call openFileForRead(iunit, m%meshFileName, errorIO)
read(iunit,'(a)',err=10,end=20,iostat=ios) m%agrid
lineNum = lineNum + 1
write(6,'(A)') "INFO: Mesh file comment line: "//trim(m%agrid)
write(6,'(A)') "INFO: Reading mesh file dimensions."

read(unit=iunit,fmt=*,err=10,end=20,iostat=ios) m%ne, m%np
do k = 1, m%np
   read(unit=iunit,fmt=*,err=10,end=20,iostat=ios) i
   lineNum = lineNum + 1
   if (i.ne.k) then
      write(6,'("ERROR: Attempted to read node number ",i0," but found node number ",i0," instead.")') k, i
      stop
   endif
enddo
do k = 1, m%ne
   read(unit=iunit,fmt=*,err=10,end=20,iostat=ios) i
   lineNum = lineNum + 1
   if (i.ne.k) then
      write(6,'("ERROR: Attempted to read element number ",i0," but found element number ",i0," instead.")') k, i
      stop
   endif
enddo
!
! return if not reading boundary table
if (m%readBoundaryTable.eqv..false.) then
   close(iunit)
   write(6,'(A)') 'INFO: Finished reading mesh file dimensions.'
   return
endif
!
!
read(unit=iunit,fmt=*,err=10,end=20,iostat=ios) m%nope  ! total number of elevation boundaries
lineNum = lineNum + 1
read(unit=iunit,fmt=*,err=10,end=20,iostat=ios) m%neta  ! total number of nodes on elevation boundaries
lineNum = lineNum + 1
write(6,'(a)') 'INFO: Allocating memory for elevation specified boundaries.'
call allocateElevationBoundaryLengths(m)
m%neta_count = 0
m%nvdll_max = 0
do k = 1, m%nope
   read(unit=iunit,fmt=*,err=10,end=20,iostat=ios) m%nvdll(k) ! number of nodes on the kth elevation boundary segment
   lineNum = lineNum + 1
   m%nvdll_max = max(m%nvdll_max,m%nvdll(k))
   do j = 1, m%nvdll(k)
      read(unit=iunit,fmt=*,err=10,end=20,iostat=ios)
      lineNum = lineNum + 1
      m%neta_count = m%neta_count + 1
   enddo
enddo
! need nvdll_max to allocate nbdv
call allocateAdcircElevationBoundaryArrays(m)
if ( m%neta_count.ne.m%neta ) then
   write(6,'("WARNING: Number of open boundary nodes was set to ",i0," but ",i0," were found.")') m%neta, m%neta_count
endif
read(unit=iunit,fmt=*,err=10,end=20,iostat=ios) m%nbou ! total number of flux boundaries
lineNum = lineNum + 1
read(unit=iunit,fmt=*,err=10,end=20,iostat=ios) m%nvel ! total number of nodes on flux boundaries
lineNum = lineNum + 1
write(6,'(a)') 'INFO: Allocating memory for flux specified boundaries.'
call allocateFluxBoundaryLengths(m)
m%nvel_count = 0
m%nvell_max = 0
do k = 1, m%nbou
   read(unit=iunit,fmt=*,err=10,end=20,iostat=ios) m%nvell(k), m%ibtype_orig(k)  ! number of nodes and type of kth flux boundary
   lineNum = lineNum + 1
   m%nvell_max = max(m%nvell_max,m%nvell(k))
   do j = 1, m%nvell(k)
      read(unit=iunit,fmt=*,err=10,end=20,iostat=ios)
      lineNum = lineNum + 1
   enddo
   ! count the total number of each type of boundary for later
   ! use in memory allocation
   select case(m%ibtype_orig(k))
   case(0,1,2,10,11,12,20,21,22,30,52)
       m%numSimpleFluxBoundaries = m%numSimpleFluxBoundaries + 1
       m%nvel_count = m%nvel_count + m%nvell(k)
   case(3,13,23)
       m%numExternalFluxBoundaries = m%numExternalFluxBoundaries + 1
       m%nvel_count = m%nvel_count + m%nvell(k)
   case(4,24)
       m%numInternalFluxBoundaries = m%numInternalFluxBoundaries + 1
       m%nvel_count = m%nvel_count + 2*m%nvell(k)
   case(5,25)
       m%numInternalFluxBoundariesWithPipes = m%numInternalFluxBoundariesWithPipes + 1
       m%nvel_count = m%nvel_count + 2*m%nvell(k)
   case default
       write(6,'("ERROR: The boundary type ",i0," was found in the file but is not valid.")') m%ibtype_orig(k)
       stop
   end select
enddo
! need nvell_max to allocate nbvv
call allocateAdcircFluxBoundaryArrays(m)
if ( m%nvel_count.ne.m%nvel) then
   write(6,'("WARNING: Number of flux boundary nodes was set to ",i0," but ",i0," were found.")') m%nvel, m%nvel_count
   if (verbose.eqv..true.) then
      write(6,*) 'WARNING: Here is the summary of land boundary node information:'
      write(6,'("NVEL (specified number of land boundary nodes) = ",i0,".")') m%nvel
      write(6,'("Counted number of land boundary nodes = ",i0,".")') m%nvel_count
      do k=1,m%nbou
         write(6,'("ibtype(",i0,")=",i0,", nvell(",i0,")=",i0,", total=",i0,".")') k, m%ibtype_orig(k), k, m%nvell(k), sum(m%nvell(1:k))
      end do
   endif
endif
close(iunit)
write(6,'(A)') 'INFO: Finished reading mesh file dimensions.'
return
   !
   ! jump to here on error and end conditions during read
10 write(6,'("ERROR: Reading line ",i0," gave the following error code: ",i0,".")')         lineNum, ios
   close(iunit)
   stop
20 write(6,'("ERROR: Reached premature end of file on line ",i0,".")') lineNum
   close(iunit)
   stop
!-----+---------+---------+---------+---------+---------+---------+
end subroutine read14_findDims
!-----+---------+---------+---------+---------+---------+---------+


!------------------------------------------------------------------
!                   S U B R O U T I N E
!        F I N D   M E S H   D I M S   N E T C D F
!------------------------------------------------------------------
! Unfinished routine to read the dimensions of mesh data from
! a netcdf file. See TODO comments at the end of the subroutine.
!------------------------------------------------------------------
subroutine findMeshDimsNetCDF(m, n)
use netcdf
use ioutil
implicit none
type(mesh_t), intent(inout) :: m ! mesh to operate on
type(meshNetCDF_t), intent(inout) :: n ! netcdf IDs to operate on
integer :: nc_id  ! netcdf ID of the file to read from
integer :: dimPres ! return code from netcdf to determine if the dimension is present in the file
integer :: i
!
write(6,'(a)') 'INFO: Reading mesh dimensions from the netCDF file.'
!
! initializations
m%is3D = .false.
!
! open the netcdf file
call check(nf90_open(trim(m%meshFileName), NF90_NOWRITE, nc_id))
!
call readMeshCommentLineNetCDF(m, nc_id)
!
! read the lengths of the dimensions that will always be present in
! an adcirc netcdf file that contains a mesh
call check(nf90_inq_dimid(nc_id, 'node', n%nc_dimid_node))
call check(nf90_inquire_dimension(nc_id, n%nc_dimid_node, len=m%np))
call check(nf90_inq_dimid(nc_id, 'nele', n%nc_dimid_nele))
call check(nf90_inquire_dimension(nc_id, n%nc_dimid_nele, len=m%ne))
!
! determine which other dimensions are present and find their lengths
!
! open boundaries
write(6,'(a)') 'INFO: Reading boundary dimensions.'
dimPres = nf90_inq_dimid(nc_id, 'nope', n%nc_dimid_nope)
if (dimPres.eq.NF90_NOERR) then
   call check(nf90_inquire_dimension(nc_id, n%nc_dimid_nope, len=m%nope))
else
   m%nope = 0
endif
! total number of open boundary nodes
dimPres = nf90_inq_dimid(nc_id, 'neta', n%nc_dimid_neta)
if (dimPres.eq.NF90_NOERR) then
   call check(nf90_inquire_dimension(nc_id, n%nc_dimid_neta, len=m%neta))
else
   m%neta = 0
endif
! longest open boundary segment
dimPres = nf90_inq_dimid(nc_id, 'max_nvdll', n%nc_dimid_max_nvdll)
if (dimPres.eq.NF90_NOERR) then
   call check(nf90_inquire_dimension(nc_id, n%nc_dimid_max_nvdll, len=m%nvdll_max))
else
   m%nvdll_max = 0
endif
! allocate arrays to hold the data
call allocateElevationBoundaryLengths(m)
call allocateAdcircElevationBoundaryArrays(m)
!
! now read in the lengths of the open boundary segments and the node
! numbers on each segment
if (m%nope.ne.0) then
   call check(nf90_inq_varid(nc_id, 'nvdll', n%nc_varid_nvdll))
   call check(nf90_get_var(nc_id, n%nc_varid_nvdll, m%nvdll, (/ 1 /), (/ m%nope /) ))
   call check(nf90_inq_varid(nc_id, 'nbdv', n%nc_varid_nbdv))
   do i=1, m%nope
      call check(nf90_get_var(nc_id, n%nc_varid_nbdv, m%nbdv(i,:), (/ i, 1 /), (/ 1, m%nvdll(i) /) ))
   end do
endif
!
! flux boundaries
dimPres = nf90_inq_dimid(nc_id, 'nbou', n%nc_dimid_nbou)
if (dimPres.eq.NF90_NOERR) then
   call check(nf90_inquire_dimension(nc_id, n%nc_dimid_nbou, len=m%nbou))
else
   m%nbou = 0
endif
! total number of flux boundary nodes
dimPres = nf90_inq_dimid(nc_id, 'nvel', n%nc_dimid_nvel)
if (dimPres.eq.NF90_NOERR) then
   call check(nf90_inquire_dimension(nc_id, n%nc_dimid_nvel, len=m%nvel))
else
   m%nvel = 0
endif
! longest flux boundary segment
dimPres = nf90_inq_dimid(nc_id, 'max_nvell', n%nc_dimid_max_nvell)
if (dimPres.eq.NF90_NOERR) then
   call check(nf90_inquire_dimension(nc_id, n%nc_dimid_max_nvell, len=m%nvell_max))
else
   m%nvell_max = 0
endif
!
call allocateFluxBoundaryLengths(m)
call allocateAdcircFluxBoundaryArrays(m)
!
! now read in the lengths of the open boundary segments and the node
! numbers on each segment
if (m%nbou.ne.0) then
   call check(nf90_inq_varid(nc_id, 'nvell', n%nc_varid_nvell))
   call check(nf90_get_var(nc_id, n%nc_varid_nvell, m%nvell, (/ 1 /), (/ m%nbou /) ))
   call check(nf90_inq_varid(nc_id, 'ibtype', n%nc_varid_ibtype))
   call check(nf90_get_var(nc_id, n%nc_varid_ibtype, m%ibtype, (/ 1 /) , (/ m%nbou /) ))
   call check(nf90_inq_varid(nc_id, 'nbvv', n%nc_varid_nbvv))
   do i=1, m%nbou
      call check(nf90_get_var(nc_id, n%nc_varid_nbvv, m%nbvv(i,:), (/ i, 1 /), (/ 1, m%nvell(i) /) ))
   end do
endif
!
! get 3D mesh dimensions if the data are 3D
i = nf90_inq_dimid(nc_id, "num_v_nodes", n%nc_dimid_nfen)
if (i.eq.NF90_NOERR) then
   m%is3D = .true.
   call check(nf90_inquire_dimension(nc_id, n%nc_dimid_nfen, len=m%nfen))
   call check(nf90_inq_varid(nc_id, "sigma", n%nc_varid_sigma))
   allocate(m%sigma(m%nfen))
   call check(nf90_get_var(nc_id, n%nc_varid_sigma, m%sigma))
endif
!
! close netcdf file
call check(nf90_close(nc_id))
write(6,'(a)') 'INFO: Finished reading mesh dimensions from the netCDF file.'
!----------------------------------------------------------------------
end subroutine findMeshDimsNetCDF
!----------------------------------------------------------------------

!------------------------------------------------------------------
!    S U B R O U T I N E     R E A D   M E S H   N E T C D F
!------------------------------------------------------------------
! Read the mesh data (coordinates, bathy/topo, element table).
! The subroutine findMeshDimsNetCDF() must be called before this
! one.
! TODO: The NetCDF files written by ADCIRC don't actually contain the
! levee heights, coefficients of sub/supercritical flow, etc.
!------------------------------------------------------------------
subroutine readMeshNetCDF(m, n)
use netcdf
use ioutil
implicit none
type(mesh_t), intent(inout) :: m ! mesh to operate on
type(meshNetCDF_t), intent(inout) :: n ! netcdf IDs to operate on
integer :: nc_id ! netcdf ID of the file to read from
integer :: i, j ! loop counter
!
integer :: nc_count(1) ! x, y, and depth are 1D
integer :: nc_start(1)
!
integer :: nc_ele_count(2) ! element table is 2D
integer :: nc_ele_start(2)
!
integer :: nc_boundmax_count(2) ! max boundary nodes table is 2D
integer :: nc_boundmax_start(2)
!
write(6,'(a)') 'INFO: Reading mesh from the netCDF file.'
call allocateNodalAndElementalArrays(m)
!
call check(nf90_open(trim(m%meshFileName), NF90_NOWRITE, nc_id))
!
! read mesh lon, lat, depth data from the file
nc_start = (/ 1 /)
nc_count = (/ m%np /)

call check(nf90_inq_varid(nc_id, 'x', n%nc_varid_x))
call check(nf90_get_var(nc_id,n%nc_varid_x,m%xyd(1,1:m%np),nc_start,nc_count))
call check(nf90_inq_varid(nc_id, 'y', n%nc_varid_y))
call check(nf90_get_var(nc_id,n%nc_varid_y,m%xyd(2,1:m%np),nc_start,nc_count))
call check(nf90_inq_varid(nc_id, 'depth', n%nc_varid_depth))
call check(nf90_get_var(nc_id,n%nc_varid_depth,m%xyd(3,1:m%np),nc_start,nc_count))
!
! element table
nc_ele_start = (/ 1, 1 /)
nc_ele_count = (/ 3, m%ne /)
call check(nf90_inq_varid(nc_id, 'element', n%nc_varid_element))
call check(nf90_get_var(nc_id,n%nc_varid_element,m%nmnc,nc_ele_start,nc_ele_count))
!
! populate the adcirc-style element table
!
! we must reverse the order of the dimensions because netcdf writes
! them to disk in column major order, according to the way C interprets
! the data, rather than row major order, the way Fortran would interpret
! the data
do i=1, m%ne
   do j=1, 3
      m%nm(i,j)= m%nmnc(j,i)
   end do
end do
!
! open (i.e., elevation specified) boundaries
if (m%nope.ne.0) then
   nc_count = (/ m%nope /)
   call check(nf90_get_var(nc_id,n%nc_varid_nvdll,m%nvdll,nc_start,nc_count))
   nc_boundmax_start = (/ 1, 1 /)
   nc_boundmax_count = (/ m%nope, m%nvdll_max /)
   call check(nf90_get_var(nc_id,n%nc_varid_nbdv,m%nbdv,nc_boundmax_start,nc_boundmax_count))
endif
if (m%nbou.ne.0) then
   nc_count = (/ m%nbou /)
   call check(nf90_get_var(nc_id,n%nc_varid_nvell,m%nvell,nc_start,nc_count))
   nc_count = (/ m%nbou /)
   call check(nf90_get_var(nc_id,n%nc_varid_ibtype,m%ibtype,nc_start,nc_count))
   nc_boundmax_start = (/ 1, 1 /)
   nc_boundmax_count = (/ m%nbou, m%nvell_max /)
   call check(nf90_get_var(nc_id,n%nc_varid_nbvv,m%nbvv,nc_boundmax_start,nc_boundmax_count))
end if
call check(nf90_close(nc_id))
write(6,'(a)') 'INFO: Mesh has been read from the netCDF file.'

!----------------------------------------------------------------------
end subroutine readMeshNetCDF
!----------------------------------------------------------------------


!------------------------------------------------------------------
!                   S U B R O U T I N E
!   R E A D   M E S H   C O M M E N T   L I N E   N E T C D F
!------------------------------------------------------------------
! Reads the mesh comment line from the netcdf file, taking into
! account the fact that this comment line has been written with
! two different variable names at different times by different
! programs.
!------------------------------------------------------------------
subroutine readMeshCommentLineNetCDF(m, nc_id)
use netcdf
use ioutil
implicit none
type(mesh_t), intent(inout) :: m ! mesh to operate on
integer, intent(in) :: nc_id ! netcdf id of the file to read from
! return codes to determine which of the variable names were
! used in writing this file
integer :: agold
integer :: agnew

agnew = nf90_get_att(nc_id,nf90_global,'agrid',m%agrid)
if (agnew.EQ.NF90_NOERR) then
   return
endif
agold = nf90_get_att(nc_id,nf90_global,'grid',m%agrid)
if (agold.EQ.NF90_NOERR) then
   return
endif
! This can happen if a minimal hotstart file was created, e.g., by adcirpolate
write(6,'(a)') 'WARNING: Could not find the fort.14 comment line (grid or agrid attribute).'
m%agrid='WARNING: Could not find the fort.14 comment line (grid or agrid attribute).'

!----------------------------------------------------------------------
end subroutine readMeshCommentLineNetCDF
!----------------------------------------------------------------------

!-----+---------+---------+---------+---------+---------+---------+
! READ14
!-----+---------+---------+---------+---------+---------+---------+
subroutine read14(m)
use ioutil
implicit none
type(mesh_t), intent(inout) :: m
integer :: i, j, k, jn, je, nhy
integer :: iunit
integer :: ios     ! i/o status
integer :: lineNum ! line number currently being read
!
! initialization
m%nfluxf = 0
!
if (trim(m%meshFileName).eq."null") then
   write(6,'(a)',advance='no') "Enter name of the mesh file: "
   read(5,'(A)') m%meshFileName
endif
!
call read14_findDims(m)
!
call allocateNodalAndElementalArrays(m)
if (m%readBoundaryTable.eqv..true.) then
   call allocateBoundaryArrays(m)
   !
   if (verbose.eqv..true.) then
      write(6,'("Number of elevation specified boundaries (nope): ",i0,".")') m%nope
      write(6,'("Number of simple flux specified boundaries (0,1,2,etc): ",i0,".")') m%numSimpleFluxBoundaries
      write(6,'("Number of external flux boundaries (3,etc): ",i0,".")') m%numExternalFluxBoundaries
      write(6,'("Number of internal flux boundaries (4,etc): ",i0,".")') m%numInternalFluxBoundaries
      write(6,'("Number of internal flux boundaries with pipes (5,etc): ",i0,".")') m%numInternalFluxBoundariesWithPipes
   endif
endif
write(6,'(A)') 'INFO: Reading mesh file coordinates, connectivity, and boundary data.'
iunit = availableUnitNumber()
call openFileForRead(iunit, m%meshFileName, ios)
lineNum = 1
read(unit=iunit,fmt='(a)',err=10,end=20,iostat=ios) m%agrid
lineNum = lineNum + 1
read(unit=iunit,fmt=*,err=10,end=20,iostat=ios) m%ne, m%np
lineNum = lineNum + 1
do k = 1, m%np
   read(unit=iunit,fmt=*,err=10,end=20,iostat=ios) jn, (m%xyd(j,k), j=1,3)
   lineNum = lineNum + 1
enddo
do k = 1, m%ne
   read(unit=iunit,fmt=*,err=10,end=20,iostat=ios) je, nhy, ( m%nm(k,j), j = 1, 3 )
   lineNum = lineNum + 1
enddo
!
! populate netcdf-style element table
do i=1, m%ne
   do j=1, 3
      m%nmnc(j,i) = m%nm(i,j)
   end do
end do
!
! return if not reading boundary table
if (m%readBoundaryTable.eqv..false.) then
   write(6,'(A)') 'INFO: Finished reading mesh file coordinates and connectivity.'
   return
endif
!
! read boundary table
read(unit=iunit,fmt=*,err=10,end=20,iostat=ios) m%nope
lineNum = lineNum + 1
read(unit=iunit,fmt=*,err=10,end=20,iostat=ios) m%neta
lineNum = lineNum + 1
do k = 1, m%nope
   read(unit=iunit,fmt=*,err=10,end=20,iostat=ios) m%nvdll(k)
   lineNum = lineNum + 1
   m%elevationBoundaries(k)%indexNum = k
   do j = 1, m%nvdll(k)
      read(unit=iunit,fmt=*,err=10,end=20,iostat=ios) m%elevationBoundaries(k)%nodes(j)
      m%nbdv(k,j) = m%elevationBoundaries(k)%nodes(j)
      lineNum = lineNum + 1
   enddo
enddo
read(unit=iunit,fmt=*,err=10,end=20,iostat=ios) m%nbou
lineNum = lineNum + 1
read(unit=iunit,fmt=*,err=10,end=20,iostat=ios) m%nvel
lineNum = lineNum + 1
m%sfCount = 1
m%efCount = 1
m%ifCount = 1
m%ifwpCount = 1
do k = 1, m%nbou
   read(unit=iunit,fmt=*,err=10,end=20,iostat=ios) m%nvell(k), m%ibtype_orig(k)
   lineNum = lineNum + 1
   select case(m%ibtype_orig(k))
   case(0,1,2,10,11,12,20,21,22,30,52)
      m%simpleFluxBoundaries(m%sfCount)%indexNum = k
      do j = 1, m%nvell(k)
         read(unit=iunit,fmt=*,err=10,end=20,iostat=ios)  &
            m%simpleFluxBoundaries(m%sfCount)%nodes(j)
         m%nbvv(k,j) = m%simpleFluxBoundaries(m%sfCount)%nodes(j)
         lineNum = lineNum + 1
      end do
      m%sfCount = m%sfCount + 1
   case(3,13,23)
      m%externalFluxBoundaries(m%efCount)%indexNum = k
      do j = 1, m%nvell(k)
         read(unit=iunit,fmt=*,err=10,end=20,iostat=ios) &
                       m%externalFluxBoundaries(m%efCount)%nodes(j), &
                       m%externalFluxBoundaries(m%efCount)%barlanht(j), &
                       m%externalFluxBoundaries(m%efCount)%barlancfsp(j)
         m%nbvv(k,j) = m%externalFluxBoundaries(m%efCount)%nodes(j)
         lineNum = lineNum + 1
      end do
      m%efCount = m%efCount + 1
   case(4,24)
      m%internalFluxBoundaries(m%ifCount)%indexNum = k
      do j = 1, m%nvell(k)
         read(unit=iunit,fmt=*,err=10,end=20,iostat=ios) &
                       m%internalFluxBoundaries(m%ifCount)%nodes(j), &
                       m%internalFluxBoundaries(m%ifCount)%ibconn(j), &
                       m%internalFluxBoundaries(m%ifCount)%barinht(j), &
                       m%internalFluxBoundaries(m%ifCount)%barincfsb(j), &
                       m%internalFluxBoundaries(m%ifCount)%barincfsp(j)
         m%nbvv(k,j) = m%internalFluxBoundaries(m%ifCount)%nodes(j)
         lineNum = lineNum + 1
      end do
      m%ifCount = m%ifCount + 1
   case(5,25)
      m%internalFluxBoundaries(m%ifwpCount)%indexNum = k
      do j = 1, m%nvell(k)
         read(unit=iunit,fmt=*,err=10,end=20,iostat=ios) &
                       m%internalFluxBoundariesWithPipes(m%ifwpCount)%nodes(j), &
                       m%internalFluxBoundariesWithPipes(m%ifwpCount)%ibconn(j), &
                       m%internalFluxBoundariesWithPipes(m%ifwpCount)%barinht(j), &
                       m%internalFluxBoundariesWithPipes(m%ifwpCount)%barincfsb(j), &
                       m%internalFluxBoundariesWithPipes(m%ifwpCount)%barincfsp(j), &
                       m%internalFluxBoundariesWithPipes(m%ifwpCount)%pipeht(j), &
                       m%internalFluxBoundariesWithPipes(m%ifwpCount)%pipecoef(j), &
                       m%internalFluxBoundariesWithPipes(m%ifwpCount)%pipediam(j)
         m%nbvv(k,j) = m%internalFluxBoundariesWithPipes(m%ifwpCount)%nodes(j)
         lineNum = lineNum + 1
      end do
      m%ifwpCount = m%ifwpCount + 1
   case default
      write(6,*) 'ERROR: IBTYPE ',m%ibtype_orig(k),' is not allowed.'
      stop
   end select
end do
close(iunit)
!
! initialize ibtype array
m%ibtype = m%ibtype_orig
!
write(6,'(A)') 'INFO: Finished reading mesh file coordinates, connectivity, and boundary data.'
return
      !
      ! jump to here on error and end conditions during read
10    write(6,'("ERROR: Reading line ",i0," gave the following error code: ",i0,".")')         lineNum, ios
      close(iunit)
      stop
20    write(6,'("ERROR: Reached premature end of file on line ",i0,".")') lineNum
      close(iunit)
      stop
!-----+---------+---------+---------+---------+---------+---------+
end subroutine read14
!-----+---------+---------+---------+---------+---------+---------+

!------------------------------------------------------------------
!                      S U B R O U T I N E
! A L L O C A T E   N O D A L   A N D   E L E M E N T A L   A R R A Y S
!------------------------------------------------------------------
! Mesh related memory allocation for any array that is
! dimensioned by the number of nodes in the mesh or the number of
! elements in the mesh. Mirrors the subroutine of the same name in
! the mesh module in adcirc.
!------------------------------------------------------------------
subroutine allocateNodalAndElementalArrays(m)
implicit none
type(mesh_t), intent(inout) :: m ! mesh to operate on
allocate(m%xyd(3,m%np))
allocate(m%nm(m%ne,3))
allocate(m%nmnc(3,m%ne))
!
! initialize to something troublesome to make it easy to spot issues
m%xyd = -99999.d0
m%nm = 0
!------------------------------------------------------------------
end subroutine allocateNodalAndElementalArrays
!------------------------------------------------------------------

!------------------------------------------------------------------
!                   S U B R O U T I N E
! A L L O C A T E   E L E V A T I O N   B O U N D A R Y   L E N G T H S
!------------------------------------------------------------------
! Allocate the arrays that hold the number of nodes on each elevation
! boundary segment
!------------------------------------------------------------------
subroutine allocateElevationBoundaryLengths(m)
implicit none
type(mesh_t), intent(inout) :: m ! mesh to operate on
allocate(m%nvdll(m%nope)) ! number of nodes on each elevation boundary segment
allocate(m%ibtypee(m%nope)) ! type of each elevation boundary segment
!
! initialize to something troublesome to make it easy to spot issues
m%ibtypee = -99999
m%nvdll = -99999
!------------------------------------------------------------------
end subroutine allocateElevationBoundaryLengths
!------------------------------------------------------------------

!------------------------------------------------------------------
!                   S U B R O U T I N E
!      A L L O C A T E  F L U X  B O U N D A R Y   L E N G T H S
!------------------------------------------------------------------
! Allocate the arrays that hold the number of nodes (primary nodes
! in the case of paired node boundaries like levees) on each flux
! boundary segment
!------------------------------------------------------------------
subroutine allocateFluxBoundaryLengths(m)
implicit none
type(mesh_t), intent(inout) :: m ! mesh to operate on
allocate(m%nvell(m%nbou)) ! number of nodes on each flux boundary segment
allocate(m%ibtype_orig(m%nbou))
allocate(m%ibtype(m%nbou))
!
! initialize to something troublesome to make it easy to spot issues
m%nvell = -99999
m%ibtype_orig = -99999
m%ibtype = -99999
!------------------------------------------------------------------
end subroutine allocateFluxBoundaryLengths
!------------------------------------------------------------------

!------------------------------------------------------------------
!                   S U B R O U T I N E
!      A L L O C A T E   A D C I R C  E L E V A T I O N
!               B O U N D A R Y  A R R A Y S
!------------------------------------------------------------------
! Allocate space for elevation boundary-related variables
!------------------------------------------------------------------
subroutine allocateAdcircElevationBoundaryArrays(m)
implicit none
type(mesh_t), intent(inout) :: m ! mesh to operate on
allocate(m%nbdv(m%nope,m%nvdll_max))
allocate(m%nbd(m%neta))
!
! initialize to something troublesome to make it easy to spot issues
m%nbdv = -99999
m%nbd = -99999
!------------------------------------------------------------------
end subroutine allocateAdcircElevationBoundaryArrays
!------------------------------------------------------------------

!------------------------------------------------------------------
!                       S U B R O U T I N E
!              A L L O C A T E  A D C I R C   F L U X
!                   B O U N D A R Y  A R R A Y S
!------------------------------------------------------------------
!     jgf51.21.11 Allocate space for flux boundary-related variables
!------------------------------------------------------------------
subroutine allocateAdcircFluxBoundaryArrays(m)
implicit none
type(mesh_t), intent(inout) :: m ! mesh to operate on
allocate ( m%nbv(m%nvel),m%lbcodei(m%nvel))
allocate ( m%nbvv(m%nbou,m%nvell_max))
!
! jgf20150723: These are never used so I commented them out because
! they are memory hogs.
!allocate ( barlanht(nbou,nvel),barlancfsp(nbou,nvel))
!allocate ( barinht(nbou,nvel),barincfsb(nbou,nvel),barincfsp(nbou,nvel))
!allocate ( pipeht(nbou,nvel),pipecoef(nbou,nvel),pipediam(nbou,nvel))
!allocate ( ibconn(nbou,nvel))
! kmd - added for rivers in baroclinic simulation
!allocate (bcrnbvv(nbou,0:nvel))
!allocate (bcrnvell(nbou))

!
! initialize to something troublesome to make it easy to spot issues
m%nbv = -99999
m%lbcodei = -99999
m%nbvv = -99999
!
! jgf20150723: These are never used so I commented them out because
! they are memory hogs.
!barlanht = -99999.d0
!barlancfsp = -99999.d0
!barinht = -99999.d0
!barincfsb = -99999.d0
!barincfsp = -99999.d0
!pipeht = -99999.d0
!pipecoef = -99999.d0
!pipediam = -99999.d0
!ibconn = -99999

!bcrnbvv = -99999
!bcrnvell = -99999
!------------------------------------------------------------------
end subroutine allocateAdcircFluxBoundaryArrays
!------------------------------------------------------------------

!------------------------------------------------------------------
!                   S U B R O U T I N E
!        A L L O C A T E  B O U N D A R Y  A R R A Y S
!------------------------------------------------------------------
! Allocate space for boundary-related variables
!------------------------------------------------------------------
subroutine allocateBoundaryArrays(m)
implicit none
type(mesh_t), intent(inout) :: m ! mesh to operate on
integer :: i
!
allocate(m%elevationBoundaries(m%nope))
do i=1,m%nope
   allocate(m%elevationBoundaries(i)%nodes(m%nvdll(i)))
end do
allocate(m%simpleFluxBoundaries(m%numSimpleFluxBoundaries))
allocate(m%externalFluxBoundaries(m%numExternalFluxBoundaries))
allocate(m%internalFluxBoundaries(m%numInternalFluxBoundaries))
allocate(m%internalFluxBoundariesWithPipes(m%numInternalFluxBoundariesWithPipes))
m%sfCount = 1
m%efCount = 1
m%ifCount = 1
m%ifwpCount = 1
do i=1,m%nbou
   if (verbose.eqv..true.) then
      write(6,'("i=",i0)') i
   endif
   select case(m%ibtype_orig(i))
   case(0,1,2,10,11,12,20,21,22,30,52)
      allocate(m%simpleFluxBoundaries(m%sfCount)%nodes(m%nvell(i)))
      m%sfCount = m%sfCount + 1
   case(3,13,23)
      allocate(m%externalFluxBoundaries(m%efCount)%nodes(m%nvell(i)))
      allocate(m%externalFluxBoundaries(m%efCount)%barlanht(m%nvell(i)))
      allocate(m%externalFluxBoundaries(m%efCount)%barlancfsp(m%nvell(i)))
      m%efCount = m%efCount + 1
   case(4,24)
      allocate(m%internalFluxBoundaries(m%ifCount)%nodes(m%nvell(i)))
      allocate(m%internalFluxBoundaries(m%ifCount)%ibconn(m%nvell(i)))
      allocate(m%internalFluxBoundaries(m%ifCount)%barinht(m%nvell(i)))
      allocate(m%internalFluxBoundaries(m%ifCount)%barincfsb(m%nvell(i)))
      allocate(m%internalFluxBoundaries(m%ifCount)%barincfsp(m%nvell(i)))
      m%ifCount = m%ifCount + 1
   case(5,25)
      allocate(m%internalFluxBoundariesWithPipes(m%ifwpCount)%nodes(m%nvell(i)))
      allocate(m%internalFluxBoundariesWithPipes(m%ifwpCount)%ibconn(m%nvell(i)))
      allocate(m%internalFluxBoundariesWithPipes(m%ifwpCount)%barinht(m%nvell(i)))
      allocate(m%internalFluxBoundariesWithPipes(m%ifwpCount)%barincfsb(m%nvell(i)))
      allocate(m%internalFluxBoundariesWithPipes(m%ifwpCount)%barincfsp(m%nvell(i)))
      allocate(m%internalFluxBoundariesWithPipes(m%ifwpCount)%pipeht(m%nvell(i)))
      allocate(m%internalFluxBoundariesWithPipes(m%ifwpCount)%pipecoef(m%nvell(i)))
      allocate(m%internalFluxBoundariesWithPipes(m%ifwpCount)%pipediam(m%nvell(i)))
      m%ifwpCount = m%ifwpCount + 1
   case default
       write(6,'("ERROR: The boundary type ",i0," was found in the file but is not valid.")') m%ibtype_orig(i)
       stop
   end select
end do
! initialize to something troublesome to make it easy to spot issues
do i=1,m%nope
   m%elevationBoundaries(i)%nodes(:) = -99999
end do
do i=1,m%numSimpleFluxBoundaries
   m%simpleFluxBoundaries(i)%nodes(:) = -99999
end do
do i=1,m%numExternalFluxBoundaries
   m%externalFluxBoundaries(i)%nodes(:) = -99999
   m%externalFluxBoundaries(i)%barlanht(:) = -99999.d0
   m%externalFluxBoundaries(i)%barlancfsp(:) = -99999.d0
end do
do i=1,m%numInternalFluxBoundaries
   m%internalFluxBoundaries(i)%nodes(:) = -99999
   m%internalFluxBoundaries(i)%ibconn(:) = -99999
   m%internalFluxBoundaries(i)%barinht(:) = -99999.d0
   m%internalFluxBoundaries(i)%barincfsb(:) = -99999.d0
   m%internalFluxBoundaries(i)%barincfsp(:) = -99999.d0
end do
do i=1,m%numInternalFluxBoundariesWithPipes
   m%internalFluxBoundariesWithPipes(i)%nodes(:) = -99999
   m%internalFluxBoundariesWithPipes(i)%ibconn(:) = -99999
   m%internalFluxBoundariesWithPipes(i)%barinht(:) = -99999.d0
   m%internalFluxBoundariesWithPipes(i)%barincfsb(:) = -99999.d0
   m%internalFluxBoundariesWithPipes(i)%barincfsp(:) = -99999.d0
   m%internalFluxBoundariesWithPipes(i)%pipeht(:) = -99999.d0
   m%internalFluxBoundariesWithPipes(i)%pipecoef(:) = -99999.d0
   m%internalFluxBoundariesWithPipes(i)%pipediam(:) = -99999.d0
end do

!------------------------------------------------------------------
end subroutine allocateBoundaryArrays
!------------------------------------------------------------------

!-----+---------+---------+---------+---------+---------+---------+
!                   S U B R O U T I N E
!  C O N S T R U C T   F L U X   B O U N D A R I E S   A R R A Y
!-----+---------+---------+---------+---------+---------+---------+
subroutine constructFluxBoundaryTypesArray(m)
implicit none
type(mesh_t), intent(inout) :: m ! mesh to operate on
integer :: i
integer :: j
integer :: k
integer :: jgw
!
jgw = 1
do k=1,m%nbou
   do j=1,m%nvell(k)
      m%lbcodei(jgw) = m%ibtype(k)
      jgw = jgw + 1
   end do
end do
! determine if there are any specified flux boundaries in the mesh
do i=1,size(specifiedFluxBoundaryTypes)
   if (any(m%lbcodei.eq.specifiedFluxBoundaryTypes(i))) then
      m%nfluxf = 1 ! => must find b.c.s in fort.15 or fort.20
      exit
   endif
end do
!-----+---------+---------+---------+---------+---------+---------+
end subroutine constructFluxBoundaryTypesArray
!-----+---------+---------+---------+---------+---------+---------+

!------------------------------------------------------------------
!   S U B R O U T I N E   W R I T E   M E S H
!------------------------------------------------------------------
!  Writes the mesh file data to adcirc ascii fort.14 format.
!------------------------------------------------------------------
subroutine writeMesh(m)
use ioutil
implicit none
type(mesh_t), intent(inout) :: m ! mesh to operate on
integer :: i, j, k, jn, je, nhy
integer :: iunit
integer :: ios     ! i/o status
integer :: lineNum ! line number currently being read
!
! initialization
m%nfluxf = 0
nhy = 3
!
if (trim(m%meshFileName).eq."null") then
   write(6,'(a)',advance='no') "Enter name of the mesh file: "
   read(5,'(a)') m%meshFileName
endif
iunit = availableUnitNumber()
open(unit=iunit,file=trim(m%meshFileName),status='replace',action='write')
if (verbose.eqv..true.) then
   write(6,'("Number of elevation specified boundaries (m%nope): ",i0,".")') m%nope
   write(6,'("Number of simple flux specified boundaries (0,1,2,etc): ",i0,".")') m%numSimpleFluxBoundaries
   write(6,'("Number of external flux boundaries (3,etc): ",i0,".")') m%numExternalFluxBoundaries
   write(6,'("Number of internal flux boundaries (4,etc): ",i0,".")') m%numInternalFluxBoundaries
   write(6,'("Number of internal flux boundaries with pipes (5,etc): ",i0,".")') m%numInternalFluxBoundariesWithPipes
endif
write(6,'(a)') 'INFO: Writing node table to "' // trim(m%meshFileName) // '".'
lineNum = 1
write(unit=iunit,fmt='(a)',err=10,iostat=ios) trim(m%agrid)
lineNum = lineNum + 1
write(unit=iunit,fmt='(2(i0,1x),a)',err=10,iostat=ios) m%ne, m%np, &
  '! number of elements (ne), number of nodes (np)'
lineNum = lineNum + 1
write(unit=iunit,fmt='(i0,3(1x,f15.7),a)',err=10,iostat=ios) &
   1, (m%xyd(j,1), j=1,3), ' ! node table: node number, x, y, depth'
lineNum = lineNum + 1
do k = 2, m%np
   write(unit=iunit,fmt='(i0,3(1x,f15.7))',err=10,iostat=ios) &
      k, (m%xyd(j,k), j=1,3)
   lineNum = lineNum + 1
enddo
write(6,'(a)') 'INFO: Writing element table to ' // trim(m%meshFileName) // '".'
write(unit=iunit,fmt='(5(i0,2x),a)',err=10,iostat=ios) 1, nhy, ( m%nm(1,j), j = 1, 3 ), &
   '! element table : element number, number of nodes per element, node numbers counter clockwise around the element '
lineNum = lineNum + 1
do k = 2, m%ne
   write(unit=iunit,fmt='(5(i0,2x))',err=10,iostat=ios) k, nhy, ( m%nm(k,j), j = 1, 3 )
   lineNum = lineNum + 1
enddo
write(6,'(a)') 'INFO: Writing boundaries to '  // trim(m%meshFileName) // '".'
write(unit=iunit,fmt='(i0,a)',err=10,iostat=ios) m%nope, &
   ' ! total number of elevation specified boundary segments (nope)'
lineNum = lineNum + 1
write(unit=iunit,fmt='(i0,a)',err=10,iostat=ios) m%neta, &
   ' ! total number of nodes on elevation specified boundaries (neta) (consistency check)'
lineNum = lineNum + 1
do k = 1, m%nope
   write(unit=iunit,fmt='(i0,1x,i0,a,i0)',err=10,iostat=ios) m%nvdll(k), 0, &
   ' ! number of nodes and boundary type of elevation specified boundary (nvdll, ibtypee) segment number ', k
   lineNum = lineNum + 1
   write(unit=iunit,fmt='(i0,a)',err=10,iostat=ios) m%elevationBoundaries(k)%nodes(1), &
      ' ! list of nodes on this elevation specified boundary segment (nbdv)'
   lineNum = lineNum + 1
   do j = 2, m%nvdll(k)
      write(unit=iunit,fmt='(i0)',err=10,iostat=ios) m%elevationBoundaries(k)%nodes(j)
      lineNum = lineNum + 1
   enddo
enddo
write(unit=iunit,fmt='(i0,a)',err=10,iostat=ios) m%nbou, &
   ' ! total number of flux boundary segments (nbou)'
lineNum = lineNum + 1
write(unit=iunit,fmt='(i0,a)',err=10,iostat=ios) m%nvel, &
   ' ! total number of nodes on flux boundaries (nvel) (consistency check)'
lineNum = lineNum + 1
m%sfCount = 1
m%efCount = 1
m%ifCount = 1
m%ifwpCount = 1
do k = 1, m%nbou
   write(unit=iunit,fmt='(2(i0,2x),a)',err=10,iostat=ios) m%nvell(k), m%ibtype_orig(k), &
      '! number of nodes and boundary type of flux boundary (m%nvell, ibtype)'
   lineNum = lineNum + 1
   select case(m%ibtype_orig(k))
   case(0,1,2,10,11,12,20,21,22,30,52)
      write(unit=iunit,fmt='(i0,a)',err=10,iostat=ios)  &
         m%simpleFluxBoundaries(m%sfCount)%nodes(1), ' ! nodes on this boundary (nbvv)'
         lineNum = lineNum + 1
      do j = 2, m%nvell(k)
         write(unit=iunit,fmt='(i0)',err=10,iostat=ios)  &
            m%simpleFluxBoundaries(m%sfCount)%nodes(j)
         lineNum = lineNum + 1
      end do
      m%sfCount = m%sfCount + 1
   case(3,13,23)
      write(unit=iunit,fmt='(i0,1x,f8.3,1x,f8.3,a)',err=10,iostat=ios) &
                       m%externalFluxBoundaries(m%efCount)%nodes(1), &
                       m%externalFluxBoundaries(m%efCount)%barlanht(1), &
                       m%externalFluxBoundaries(m%efCount)%barlancfsp(1), &
      ' ! boundary node (nbvv), barrier height (barlanht), and coef of. supercritical flow (barlancfsp)'
      lineNum = lineNum + 1
      do j = 2, m%nvell(k)
         write(unit=iunit,fmt='(i0,1x,f8.3,1x,f8.3)',err=10,iostat=ios) &
                       m%externalFluxBoundaries(m%efCount)%nodes(j), &
                       m%externalFluxBoundaries(m%efCount)%barlanht(j), &
                       m%externalFluxBoundaries(m%efCount)%barlancfsp(j)
         lineNum = lineNum + 1
      end do
      m%efCount = m%efCount + 1
   case(4,24)
      write(unit=iunit,fmt=*,err=10,iostat=ios) &
                       m%internalFluxBoundaries(m%ifCount)%nodes(1), &
                       m%internalFluxBoundaries(m%ifCount)%ibconn(1), &
                       m%internalFluxBoundaries(m%ifCount)%barinht(1), &
                       m%internalFluxBoundaries(m%ifCount)%barincfsb(1), &
                       m%internalFluxBoundaries(m%ifCount)%barincfsp(1), &
      ' ! boundary node (nbvv), connected backface node (ibconn), ' // &
      'barrier height (barinht), coef. of subcrit. flow (barincfsb), ' // &
      'coef. of supercrit. flow (barincfsp) '
      lineNum = lineNum + 1
      do j = 2, m%nvell(k)
         write(unit=iunit,fmt='(2(i0,1x),3(f8.3,1x))',err=10,iostat=ios) &
                       m%internalFluxBoundaries(m%ifCount)%nodes(j), &
                       m%internalFluxBoundaries(m%ifCount)%ibconn(j), &
                       m%internalFluxBoundaries(m%ifCount)%barinht(j), &
                       m%internalFluxBoundaries(m%ifCount)%barincfsb(j), &
                       m%internalFluxBoundaries(m%ifCount)%barincfsp(j)
         lineNum = lineNum + 1
      end do
      m%ifCount = m%ifCount + 1
   case(5,25)
      write(unit=iunit,fmt='(2(i0,1x),6(f8.3),a)',err=10,iostat=ios) &
                    m%internalFluxBoundariesWithPipes(m%ifCount)%nodes(1), &
                    m%internalFluxBoundariesWithPipes(m%ifCount)%ibconn(1), &
                    m%internalFluxBoundariesWithPipes(m%ifCount)%barinht(1), &
                    m%internalFluxBoundariesWithPipes(m%ifCount)%barincfsb(1), &
                    m%internalFluxBoundariesWithPipes(m%ifCount)%barincfsp(1), &
                    m%internalFluxBoundariesWithPipes(m%ifCount)%pipeht(1), &
                    m%internalFluxBoundariesWithPipes(m%ifCount)%pipecoef(1), &
                    m%internalFluxBoundariesWithPipes(m%ifCount)%pipediam(1), &
      ' ! boundary node (nbvv), connected backface node (ibconn), ' // &
      'barrier height (barinht), coef. of subcrit. flow (barincfsb), ' // &
      'coef. of supercrit. flow (barincfsp), pipe height (pipeht), ' // &
      ' pipe coef. (pipecoef), pipediameter(pipediam)'
      lineNum = lineNum + 1
      do j = 2, m%nvell(k)
         write(unit=iunit,fmt='(2(i0,1x),6(f8.3))',err=10,iostat=ios) &
                       m%internalFluxBoundariesWithPipes(m%ifCount)%nodes(j), &
                       m%internalFluxBoundariesWithPipes(m%ifCount)%ibconn(j), &
                       m%internalFluxBoundariesWithPipes(m%ifCount)%barinht(j), &
                       m%internalFluxBoundariesWithPipes(m%ifCount)%barincfsb(j), &
                       m%internalFluxBoundariesWithPipes(m%ifCount)%barincfsp(j), &
                       m%internalFluxBoundariesWithPipes(m%ifCount)%pipeht(j), &
                       m%internalFluxBoundariesWithPipes(m%ifCount)%pipecoef(j), &
                       m%internalFluxBoundariesWithPipes(m%ifCount)%pipediam(j)
         lineNum = lineNum + 1
      end do
      m%ifwpCount = m%ifwpCount + 1
   case default
      write(6,'("ERROR: IBTYPE ",i0," is not allowed.")') m%ibtype_orig(k)
      stop
   end select
end do
close(iunit)
write(6,'(a)') 'INFO: Finished writing ascii mesh file.'
return
      !
      ! jump to here on error and end conditions during read
10    write(6,'("ERROR: The error code ",i0," occurred when writing line ",i0,".")')         ios, lineNum
      close(iunit)
      stop
!------------------------------------------------------------------
end subroutine writeMesh
!------------------------------------------------------------------

!----------------------------------------------------------------------
!                  S U B R O U T I N E
!     W R I T E   M E S H   D E F I N I T I O N S  T O   N E T C D F
!----------------------------------------------------------------------
!     This subroutine writes the mesh parameters to the netcdf file.
!----------------------------------------------------------------------
subroutine writeMeshDefinitionsToNetCDF(m, n, nc_id, deflate)
use netcdf
use ioutil
implicit none
type(mesh_t), intent(inout) :: m ! mesh to operate on
type(meshNetCDF_t), intent(inout) :: n ! netcdf IDs for the target file
integer, intent(in) :: nc_id
logical, intent(in) :: deflate
integer             :: NC_DimID_single
integer :: ncStatus
!
! create and store mesh dimensions
write(6,'(a)') 'INFO: Writing mesh definitions to netcdf.'
CALL Check(NF90_PUT_ATT(NC_ID,NF90_GLOBAL,'agrid',trim(m%agrid)))
! check to see if the node dimension is already there
ncStatus = nf90_inq_dimid(NC_ID,'node',n%NC_DimID_node)
if ( ncStatus.ne.NF90_NOERR ) then
   CALL Check(NF90_DEF_DIM(NC_ID,'node',m%np,n%NC_DimID_node))
endif
ncStatus = nf90_inq_dimid(NC_ID,'nele',n%NC_DimID_nele)
if ( ncStatus.ne.NF90_NOERR ) then
   CALL Check(NF90_DEF_DIM(NC_ID,'nele',m%ne,n%NC_DimID_nele))
endif
CALL Check(NF90_DEF_DIM(NC_ID,'nvertex',3,n%NC_DimID_nvertex))
CALL Check(NF90_DEF_DIM(NC_ID,'single',1,NC_DimID_single))
! boundary parameters
if (m%readBoundaryTable.eqv..true.) then
   if (m%nope.ne.0) CALL Check(NF90_DEF_DIM(NC_ID,'m%nope',m%nope,n%NC_DimID_nope))
   if (m%nvdll_max.ne.0) CALL Check(NF90_DEF_DIM(NC_ID,'max_nvdll',m%nvdll_max,n%NC_DimID_max_nvdll))
   if (m%neta.ne.0) CALL Check(NF90_DEF_DIM(NC_ID,'neta',m%neta,n%NC_DimID_neta))
   if (m%nbou.ne.0) CALL Check(NF90_DEF_DIM(NC_ID,'nbou',m%nbou,n%NC_DimID_nbou))
   if (m%nvel.ne.0) CALL Check(NF90_DEF_DIM(NC_ID,'nvel',m%nvel,n%NC_DimID_nvel))
   if (m%nvell_max.ne.0) CALL Check(NF90_DEF_DIM(NC_ID,'max_m%nvell',m%nvell_max,n%NC_DimID_max_nvell))
endif
! ibtypee, ibconn, bars are ignored
CALL Check(NF90_DEF_VAR(NC_ID,'x',NF90_DOUBLE,n%NC_DimID_node,n%NC_VarID_x))
CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_x,'long_name','longitude'))
CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_x,'standard_name','longitude'))
CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_x,'units','degrees_east'))
CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_x,'positive','east'))

CALL Check(NF90_DEF_VAR(NC_ID,'y',NF90_DOUBLE,n%NC_DimID_node,n%NC_VarID_y))
CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_y,'long_name','latitude'))
CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_y,'standard_name','latitude'))
CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_y,'units','degrees_north'))
CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_y,'positive','north'))

CALL Check(NF90_DEF_VAR(NC_ID,'element',NF90_int,(/ n%NC_DimID_nvertex, n%NC_DimID_nele /), n%NC_VarID_element))
CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_element,'long_name','element'))
CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_element,'standard_name','face_node_connectivity'))
CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_element,'units','nondimensional'))
CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_element,'start_index',1))

if (m%readBoundaryTable.eqv..true.) then
   if (m%nope.ne.0) then
      CALL Check(NF90_DEF_VAR(NC_ID,'nvdll',NF90_DOUBLE,n%NC_DimID_nope,n%NC_VarID_nvdll))
      CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_nvdll,'long_name','total number of nodes in each elevation specified & boundary segment'))
      CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_nvdll,'units','nondimensional'))

      CALL Check(NF90_DEF_VAR(NC_ID,'max_nvdll',NF90_int,NC_DimID_single,n%NC_VarID_max_nvdll))
      CALL Check(NF90_DEF_VAR(NC_ID,'max_nvell',NF90_int,NC_DimID_single,n%NC_VarID_max_nvell))
      CALL Check(NF90_DEF_VAR(NC_ID,'neta',NF90_int,NC_DimID_single,n%NC_VarID_neta))
      CALL Check(NF90_DEF_VAR(NC_ID,'nope',NF90_int,NC_DimID_single,n%NC_VarID_nope))
      CALL Check(NF90_DEF_VAR(NC_ID,'nvel',NF90_int,NC_DimID_single,n%NC_VarID_nvel))

      CALL Check(NF90_DEF_VAR(NC_ID,'nbdv',NF90_DOUBLE,(/ n%NC_DimID_nope, n%NC_DimID_max_nvdll /), n%NC_VarID_nbdv))
      CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_nbdv,'long_name','node numbers on each elevation specified boundary & segment'))
      CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_nbdv,'units','nondimensional'))
   endif

   if (m%nbou.ne.0) then
      CALL Check(NF90_DEF_VAR(NC_ID,'nvell',NF90_DOUBLE,n%NC_DimID_nbou,n%NC_VarID_nvell))
      CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_nvell,'long_name','number of nodes in each normal flow specified boundary segment'))
      CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_nvell,'units','nondimensional'))

      CALL Check(NF90_DEF_VAR(NC_ID,'ibtype',NF90_DOUBLE,n%NC_DimID_nbou,n%NC_VarID_ibtype))
      CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_ibtype,'long_name','type of normal flow (discharge) boundary'))
      CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_ibtype,'units','nondimensional'))

      CALL Check(NF90_DEF_VAR(NC_ID,'nbvv',NF90_DOUBLE,(/ n%NC_DimID_nbou, n%NC_DimID_max_nvell /),n%NC_VarID_nbvv))
      CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_nbvv,'long_name','node numbers on normal flow boundary segment'))
      CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_nbvv,'units','nondimensional'))
   endif
endif

CALL Check(NF90_DEF_VAR(NC_ID,'depth',NF90_DOUBLE,n%NC_DimID_node,n%NC_VarID_depth))
CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_depth,'long_name','distance from geoid'))
CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_depth,'standard_name','depth_below_geoid'))
CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_depth,'coordinates','time y x'))
CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_depth,'location','node'))
CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_depth,'mesh','adcirc_mesh'))
CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_depth,'units','m'))
!      CALL Check(NF90_PUT_ATT(NC_ID,NC_VarID_depth,'positive','down')) !DO NOT USE?

CALL Check(NF90_DEF_VAR(NC_ID,'adcirc_mesh',NF90_INT,NC_DimID_single,n%NC_VarID_mesh))
CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_mesh,'long_name','mesh topology'))
CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_mesh,'standard_name','mesh_topology'))
CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_mesh,'dimension',2))
CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_mesh,'node_coordinates','x y'))
CALL Check(NF90_PUT_ATT(NC_ID,n%NC_VarID_mesh,'face_node_connectivity','element'))

#ifdef NETCDF_CAN_DEFLATE

! automatically turn on compression if it is available
if (deflate.eqv..true.) then
   if (m%readBoundaryTable.eqv..true.) then
      if (m%nope.ne.0) then
         call check(nf90_def_var_deflate(NC_ID, n%NC_VarID_nvdll, 0, 1, 2))
         call check(nf90_def_var_deflate(NC_ID, n%NC_VarID_nbdv, 0, 1, 2))
      endif
      if (m%nbou.ne.0) then
         call check(nf90_def_var_deflate(NC_ID, n%NC_VarID_nvell, 0, 1, 2))
         call check(nf90_def_var_deflate(NC_ID, n%NC_VarID_ibtype, 0, 1, 2))
         call check(nf90_def_var_deflate(NC_ID, n%NC_VarID_nbvv, 0, 1, 2))
      endif
   endif
   call check(nf90_def_var_deflate(NC_ID, n%NC_VarID_x, 0, 1, 2))
   call check(nf90_def_var_deflate(NC_ID, n%NC_VarID_y, 0, 1, 2))
   call check(nf90_def_var_deflate(NC_ID, n%NC_VarID_element, 0, 1, 2))
   call check(nf90_def_var_deflate(NC_ID, n%NC_VarID_depth, 0, 1, 2))
   call check(nf90_def_var_deflate(NC_ID, n%NC_VarID_Mesh, 0, 1, 2))
endif

#endif

write(6,'(a)') 'INFO: Finished writing mesh definitions to netcdf.'
!----------------------------------------------------------------------
end subroutine writeMeshDefinitionsToNetCDF
!----------------------------------------------------------------------

!----------------------------------------------------------------------
!                    S U B R O U T I N E
!         W R I T E   M E S H   D A T A   T O   N E T C D F
!----------------------------------------------------------------------
!     This subroutine writes the mesh parameters to the netcdf file.
!----------------------------------------------------------------------
subroutine writeMeshDataToNetCDF(m, n, nc_id)
use netcdf
use ioutil
implicit none
type(mesh_t), intent(inout) :: m ! mesh to operate on
type(meshNetCDF_t), intent(inout) :: n ! netcdf IDs to operate on
integer, intent(in) :: nc_id
integer :: nc_count(2)
integer :: nc_start(2)
integer :: i, j

! place mesh-related data into the file
NC_Count = (/ m%np, 1 /)
NC_Start = (/ 1, 1 /)
CALL Check(NF90_PUT_VAR(NC_ID,n%NC_VarID_x,m%xyd(1,1:m%np),NC_Start,NC_Count))
CALL Check(NF90_PUT_VAR(NC_ID,n%NC_VarID_y,m%xyd(2,1:m%np),NC_Start,NC_Count))
CALL Check(NF90_PUT_VAR(NC_ID,n%NC_VarID_depth,m%xyd(3,1:m%np),NC_Start,NC_Count))
NC_Count = (/ 3, m%ne /)

CALL Check(NF90_PUT_VAR(NC_ID,n%NC_VarID_element,m%nmnc,NC_Start,NC_Count))
!
! boundary parameters
if (m%readBoundaryTable.eqv..false.) then
   write(6,'(a)') 'INFO: Mesh has been written to the netCDF file.'
   return
endif
if (m%nope.ne.0) then
   CALL Check(NF90_PUT_VAR(NC_ID,n%NC_VarID_nope,m%nope))
   CALL Check(NF90_PUT_VAR(NC_ID,n%NC_VarID_max_nvell,m%nvell_max))
   CALL Check(NF90_PUT_VAR(NC_ID,n%NC_VarID_max_nvdll,m%nvdll_max))
   CALL Check(NF90_PUT_VAR(NC_ID,n%NC_VarID_neta,m%neta))
   CALL Check(NF90_PUT_VAR(NC_ID,n%NC_VarID_nvel,m%nvel))
   NC_Count = (/ m%nope, 1 /)
   CALL Check(NF90_PUT_VAR(NC_ID,n%NC_VarID_nvdll,m%nvdll,NC_Start,NC_Count))
   NC_Count = (/ m%nope, m%nvdll_max /)
   CALL Check(NF90_PUT_VAR(NC_ID,n%NC_VarID_nbdv,m%nbdv,NC_Start,NC_Count))
endif
if (m%nbou.ne.0) then
   NC_Count = (/ m%nbou, 1 /)
   CALL Check(NF90_PUT_VAR(NC_ID,n%NC_VarID_nvell,m%nvell,NC_Start,NC_Count))
   NC_Count = (/ m%nbou, 1 /)
   CALL Check(NF90_PUT_VAR(NC_ID,n%NC_VarID_ibtype,m%ibtype,NC_Start,NC_Count))
   NC_Count = (/ m%nbou, m%nvell_max /)
   CALL Check(NF90_PUT_VAR(NC_ID,n%NC_VarID_nbvv,m%nbvv,NC_Start,NC_Count))
end if

write(6,'(a)') 'INFO: Mesh has been written to the netCDF file.'
!----------------------------------------------------------------------
end subroutine writeMeshDataToNetCDF
!----------------------------------------------------------------------

!----------------------------------------------------------------------
! S U B R O U T I N E    C O M P U T E   N E I G H B O R   T A B L E
!-----------------------------------------------------------------------
!
!  Subroutine to generate neighbor tables from a connectivity table.
!
!  NOTES
!  a node neighbor table is generated with the node itself is listed as
!     neighbor #1 and all other neighbors are sorted and placed in cw
!     order from east
!  a neighbor element table is generated with:
!     entry 1 = element # defined by neighbors 1,2,3
!     entry 2 = element # defined by neighbors 1,3,4
!     entry 3 = element # defined by neighbors 1,4,5
!      .......
!     entry last = element # defined by neighbors 1,nneigh,2
!     a zero area means that the defined triangle lies outside the domain
!
!
!    v1.0   R.L.   6/29/99  used in 3D code
!    v2.0   R.L.   5/23/02  adapted to provide neighbor el table
!-----------------------------------------------------------------------
!
! -  PARAMETERS WHICH MUST BE SET TO CONTROL THE DIMENSIONING OF ARRAYS
!       ARE AS FOLLOWS:
!
!     MNP = MAXIMUM NUMBER OF NODAL POINTS
!     MNE = MAXIMUM NUMBER OF ELEMENTS
!     MNEI= 1+MAXIMUM NUMBER OF NODES CONNECTED TO ANY ONE NODE IN THE
!              FINITE ELEMENT GRID
!
!-----------------------------------------------------------------------
!
! VARIABLE DEFINITIONS:
!   NE - NUMBER OF ELEMENTS
!   NP - NUMBER OF NODES
!   NM(MNE,3) - NODE NUMBERS ASSOCIATED WITH EACH ELEMENT
!   NNeigh(MNP) NUMBER OF NEIGHBORS FOR EACH NODE
!   NeiTab(MNP,NEIMAX) 2D ARRAY OF NEIGHBORS FOR EACH NODE
!   NeiTabEle(MNP,NEIMAX) 2D ARRAY OF NEIGHBOR ELEMENTS FOR EACH NODE
!   nNeighEle(MNP) Number of neighbor elements at each node
!   NEIMIN - 1+MINIMUM NUMBER OF NEIGHBORS FOR ANY NODE
!   NEIMAX - 1+MAXIMUM NUMBER OF NEIGHBORS FOR ANY NODE
!
!-----------------------------------------------------------------------
subroutine computeNeighborTable(m)
implicit none
type(mesh_t), intent(inout) :: m ! mesh to operate on
double precision, allocatable :: angle(:)
integer, allocatable :: neitem(:)
double precision :: anglelow
double precision :: anglemore
double precision :: delx
double precision :: dely
double precision :: dist
integer :: nn1, nn2, nn3 ! node numbers around an element
integer :: ne1, ne2, ne3 ! element numbers
integer :: i, j, jj, jlow, k, n  ! loop counters
!
! Initialization
if (m%cppComputed.eqv..false.) then
   call computeCPP(m)
endif
jlow = 0
ne2 = 0
ne3 = 0
!
! For interior nodes, the number of neighbor nodes around any node is
! equal to the number of elements that contain that node. Boundary nodes
! will have one additional neighboring node.
allocate(m%nneigh(m%np))
m%nneigh = 0
do i=1,m%ne
   do j=1,3
      ! increment the number of nodal neighbors this node has
      m%nneigh(m%nm(i,j)) = m%nneigh(m%nm(i,j)) + 1
   end do
end do
m%mnei = maxval(m%nneigh)
m%mnei = m%mnei + 2 ! +1 to include the node itself, +1 in case its a boundary node
!
allocate(m%neitab(m%np,m%mnei))
allocate(m%neitabele(m%np,m%mnei))
allocate(angle(m%mnei))
allocate(m%nneighele(m%np))
m%neighborTableComputed = .true.
allocate(m%neiTabGenerated(m%np,m%mnei))
allocate(m%neiTabEleGenerated(m%np,m%mnei))
!
! initialize neighbor tables to invalid values to make it easy to
! spot issues
m%NNeigh=0
m%NNeighEle=0
m%NeiTab=-99
m%NeiTabEle=-99
DO 10 N=1,m%NE
   NN1 = m%NM(N,1)
   NN2 = m%NM(N,2)
   NN3 = m%NM(N,3)
   m%NNeighEle(NN1)=m%NNeighEle(NN1)+1 ! increment the number of elements that neighbor this node
   m%NNeighEle(NN2)=m%NNeighEle(NN2)+1
   m%NNeighEle(NN3)=m%NNeighEle(NN3)+1
   m%NeiTabEle(NN1,m%NNeighEle(NN1))=N ! add element n to the neighboring elements list for this node
   m%NeiTabEle(NN2,m%NNeighEle(NN2))=N
   m%NeiTabEle(NN3,m%NNeighEle(NN3))=N
   !
   ! repeat for the number of nodal neighbors of node 1 on element n
   DO J=1,m%NNeigh(NN1)
      ! check to see if node 2 is already in node 1's neighbor list; if so skip adding it
      IF(NN2.EQ.m%NeiTab(NN1,J)) GOTO 25
   END DO
   m%NNeigh(NN1)=m%NNeigh(NN1)+1 ! increment the number of neighbors of node 1 on element n
   m%NNeigh(NN2)=m%NNeigh(NN2)+1 ! increment the number of neighbors of node 2 on element n
   ! if the number of neighbors on node 1 or node 2 of element n exceeds the limit, terminate
   IF((m%NNeigh(NN1).GT.m%MNEI-1).OR.(m%NNeigh(NN2).GT.m%MNEI-1)) GOTO 999
   ! add node 1 and node 2 to each other's neighbor lists
   m%NeiTab(NN1,m%NNeigh(NN1))=NN2
   m%NeiTab(NN2,m%NNeigh(NN2))=NN1

25      CONTINUE
   DO J=1,m%NNeigh(NN1)
      IF(NN3.EQ.m%NeiTab(NN1,J)) GOTO 35
   END DO
   m%NNeigh(NN1)=m%NNeigh(NN1)+1
   m%NNeigh(NN3)=m%NNeigh(NN3)+1
   IF((m%NNeigh(NN1).GT.m%MNEI-1).OR.(m%NNeigh(NN3).GT.m%MNEI-1)) GOTO 999
   m%NeiTab(NN1,m%NNeigh(NN1))=NN3
   m%NeiTab(NN3,m%NNeigh(NN3))=NN1

35      CONTINUE
   DO J=1,m%NNeigh(NN2)
      IF(NN3.EQ.m%NeiTab(NN2,J)) GOTO 10
   END DO
   m%NNeigh(NN2)=m%NNeigh(NN2)+1
   m%NNeigh(NN3)=m%NNeigh(NN3)+1
   IF((m%NNeigh(NN2).GT.m%MNEI-1).OR.(m%NNeigh(NN3).GT.m%MNEI-1)) GOTO 999
   m%NeiTab(NN2,m%NNeigh(NN2))=NN3
   m%NeiTab(NN3,m%NNeigh(NN3))=NN2

10   CONTINUE
m%neiTabGenerated = m%neiTab
m%neiTabEleGenerated = m%neiTabEle
!
!     INSERT NODE ITSELF IN PLACE #1 and SORT other NEIGHBORS by
!     increasing cw angle from East
!
! loop over nodes
allocate(neitem(m%mnei))
DO I=1,m%NP
   ! loop over nodal neighbors of node i
   DO J=1,m%NNeigh(I)
      ! save the node number of the jth neighbor of node i
      NEITEM(J)=m%NeiTab(I,J)
      ! compute the distance from the jth neighbor of node i to node i
      DELX=m%x_cpp(NEITEM(J))-m%x_cpp(I)
      DELY=m%y_cpp(NEITEM(J))-m%y_cpp(I)
      DIST=SQRT(DELX*DELX+DELY*DELY)
      ! check for identical coordinates
      IF(DIST.EQ.0.0d0) GOTO 998
      ! compute the trigonometric angle between node i and
      ! its jth neighbor in degrees
      IF(DELY.NE.0.0d0) THEN
         ANGLE(J)=RAD2DEG*ACOS(DELX/DIST)
         IF(DELY.GT.0.0) ANGLE(J)=360.0d0-ANGLE(J)
      ENDIF
      IF(DELY.EQ.0.0d0) THEN
         IF(DELX.GT.0.0d0) ANGLE(J)=0.0d0
         IF(DELX.LT.0.d0) ANGLE(J)=180.0d0
      ENDIF
   END DO
   ANGLEMORE=-1.d0
   ! repeat for the number of neighbors of node i
   DO JJ=1,m%NNeigh(I)
      ! initialize the value of the low angle???
      ANGLELOW=400.d0
      ! loop over the neighbors of node i
      DO J=1,m%NNeigh(I)
         IF((ANGLE(J).LT.ANGLELOW).AND.(ANGLE(J).GT.ANGLEMORE)) THEN
            ANGLELOW=ANGLE(J)
            JLOW=J
         ENDIF
      END DO
      m%NeiTab(I,JJ+1)=NEITEM(JLOW)
      ANGLEMORE=ANGLELOW
   END DO
   m%NeiTab(I,1)=I
   m%NNeigh(I)=m%NNeigh(I)+1
ENDDO
!
!     MATCH EACH SET OF 3 NODES WITH CORRESPONDING ELEMENT AND REORDER
!     ELEMENTS ACCORDINGLY
!
DO I=1,m%NP
   ! temporarily save the existing array of neighboring elements for this node
   neiTem(:)=-99
   DO K=1,m%NNeighEle(I)
      NEITEM(K)=m%NeiTabEle(I,K)
      m%NeiTabEle(I,K)=-99
   END DO
   ! loop over the nodal neighbors of node i
   DO J=2,m%NNeigh(I)
      NN1=m%NeiTab(I,1) ! node 1 is the node itself (node i)
      NN3=m%NeiTab(I,J) ! node 3 is the Jth nodal neighbor of this node
      !
      ! if j is not the last neighbor then node 2 is the J+1th nodal neighbor
      if (J.NE.m%NNeigh(I)) then
         NN2=m%NeiTab(I,J+1)
      endif
      !
      ! if j is the last neighbor, then node 2 is the first nodal neighbor
      if (J.EQ.m%NNeigh(I)) then
         NN2=m%NeiTab(I,2)
      endif
      !
      ! loop over the elemental neighbors of node i
      DO K=1,m%nNeighEle(I)
         ! if the neighboring element number is not uninitialized
         ! (why do we need to check this??)
         IF((NEITEM(K).NE.-99).and.(neitem(k).ne.0)) THEN
            ! if resident node 1 of the kth elemental neighbor is the same
            ! as node i, then set the node order 1, 2, 3
            IF(m%NM(NEITEM(K),1).EQ.NN1) THEN
               NE1=m%NM(NEITEM(K),1)
               NE2=m%NM(NEITEM(K),2)
               NE3=m%NM(NEITEM(K),3)
            ENDIF
            ! if resident node 2 of the kth elemental neighbor is the same
            ! as node i, then set the node order 2, 3, 1
            IF(m%NM(NEITEM(K),2).EQ.NN1) THEN
               NE1=m%NM(NEITEM(K),2)
               NE2=m%NM(NEITEM(K),3)
               NE3=m%NM(NEITEM(K),1)
            ENDIF
            ! if resident node 3 of the kth elemental neighbor is the same
            ! as node i, then set the node order 3, 1, 2
            IF(m%NM(NEITEM(K),3).EQ.NN1) THEN
               NE1=m%NM(NEITEM(K),3)
               NE2=m%NM(NEITEM(K),1)
               NE3=m%NM(NEITEM(K),2)
            ENDIF
            ! if
            IF((NE2.EQ.NN2).AND.(NE3.EQ.NN3)) THEN
               m%NeiTabEle(I,J-1)=NEITEM(K)
               NEITEM(K)=0
            ENDIF
         else
            ! there is no element corresponding to these nodes
         ENDIF
      END DO
   END DO
END DO
!
!  DETERMINE THE MAXIMUM AND MINIMUM NUMBER OF NEIGHBORS
m%NEIMAX = maxval(m%NNeigh)
m%NEIMIN = minval(m%NNeigh)
!  Deallocate local work arrays
deallocate ( angle )
deallocate ( neitem )
return

999  CONTINUE
WRITE(6,'("ERROR: Computation of neighbor table failed.")')
STOP
998  CONTINUE
WRITE(6,'("ERROR: Nodes ",i0," and ",i0," have the same coordinates.")') i, neiTem(j)
STOP
!-----------------------------------------------------------------------
END SUBROUTINE computeNeighborTable
!-----------------------------------------------------------------------


!-----------------------------------------------------------------------
!                         S U B R O U T I N E
!   C O M P U T E   N E I G H B O R   E D G E   L E N G T H   T A B L E
!-----------------------------------------------------------------------
!     jgf: Very short subroutine to compute the length of each edge
!     attached to a node. Also finds the minimum edge length in the mesh.
!-----------------------------------------------------------------------
subroutine computeNeighborEdgeLengthTable(m)
implicit none
type(mesh_t), intent(inout) :: m  ! mesh to operate on
integer i,j
allocate(m%neighborEdgeLengthTable(m%np,m%neimax))
m%neighborEdgeLengthTableComputed = .true.
m%minEdgeLength = huge(1.d0)
m%maxEdgeLength = tiny(1.d0)
do i=1,m%np
   m%neighborEdgeLengthTable(i,1) = 0.d0 ! distance from this node to itself...
   do j=2,m%nneigh(i)
      m%neighborEdgeLengthTable(i,j) = sqrt( (m%x_cpp(i)-m%x_cpp(m%NeiTab(i,j)))**2 &
                  + (m%y_cpp(i)-m%y_cpp(m%NeiTab(i,j)))**2 )
      if ( m%neighborEdgeLengthTable(i,j).lt.m%minEdgeLength ) then
         m%minEdgeLength = m%neighborEdgeLengthTable(i,j)
      endif
      if ( m%neighborEdgeLengthTable(i,j).gt.m%maxEdgeLength ) then
         m%maxEdgeLength = m%neighborEdgeLengthTable(i,j)
      endif
   end do
end do
!-----------------------------------------------------------------------
end subroutine computeNeighborEdgeLengthTable
!-----------------------------------------------------------------------

!-----------------------------------------------------------------------
!                         S U B R O U T I N E
!     C O M P U T E  A L B E R S   E Q U A L   A R E A   C O N I C
!-----------------------------------------------------------------------
!     jgf: Very short subroutine to compute the albers equal area
!     conic projection of the mesh node locations, allocating memory
!     in the process if necessary, and not overwriting the
!     original lat/lon data.
!-----------------------------------------------------------------------
SUBROUTINE computeAlbersEqualAreaConic(m)
IMPLICIT NONE
type(mesh_t), intent(inout) :: m ! mesh to operate on
real(8), parameter :: PHI1 = 29.5d0
real(8), parameter :: PHI2 = 45.5d0
real(8), parameter :: LON0 = -96.0d0
real(8), parameter :: LAT0 = 23.0d0
real(8), parameter :: EE = 0.0066943800229d0
real(8), parameter :: E = 0.0818191910428d0
!
! variables used in conversion of adcirc mesh point locations
! (in geographic projection) to Albers Equal Area Conic
real(8) :: alpha
real(8) :: alpha0
real(8) :: alpha1
real(8) :: alpha2
real(8) :: alphaa
real(8) :: alphab
real(8) :: alphac
real(8) :: c
real(8) :: e1
real(8) :: m1
real(8) :: m2
real(8) :: o
real(8) :: p
real(8) :: rho
real(8) :: rho0
real(8) :: theta
real(8) :: n
integer :: i ! loop counter
!
if (m%albersComputed.eqv..false.) then
   allocate(m%xalbers(m%np),m%yalbers(m%np))
   m%albersComputed = .true.
endif
write(6,'("INFO: Generating Albers Equal Area Conic coordinates.")')
e1 = 1.d0-ee
o = (0.5d0/e)*e1
m1 = cos(phi1*deg2rad)/(1.d0-ee*sin(phi1*deg2rad)**2)**0.5d0
m2 = cos(phi2*deg2rad)/(1.d0-ee*sin(phi2*deg2rad)**2)**0.5d0
alphaa = (0.5d0/e)*log((1.d0-e*sin(lat0*deg2rad))/(1.d0+e*sin(lat0*deg2rad)))
alpha0 = e1*sin(lat0*deg2rad)/(1.d0-ee*dsin(lat0*deg2rad)**2)-e1*alphaa
alphab = (0.5d0/e)*log((1.d0-e*sin(phi1*deg2rad))/(1.d0+e*sin(phi1*deg2rad)))
alpha1 = e1*sin(phi1*deg2rad)/(1.d0-ee*dsin(phi1*deg2rad)**2)-e1*alphab
alphac = (0.5d0/e)*log((1.d0-e*sin(phi2*deg2rad))/(1.d0+e*sin(phi2*deg2rad)))
alpha2 = e1*sin(phi2*deg2rad)/(1.d0-ee*dsin(phi2*deg2rad)**2)-e1*alphac
n = (m1**2-m2**2)/(alpha2-alpha1)
c = m1**2+n*alpha1
rho0 = r*((c-n*alpha0)**(0.5d0))/n
do i=1,m%np
   ! project mesh node locations into albers equal area conic
   P = O*DLOG((1.d0-E*DSIN(m%xyd(2,i)*deg2rad))/(1.d0+E*DSIN(m%xyd(2,i)*deg2rad)))
   ALPHA = E1*DSIN(m%xyd(2,i)*deg2rad)/(1.d0-EE*DSIN(m%xyd(2,i)*deg2rad)**2)-P
   THETA = N*(m%xyd(1,i)-LON0)
   RHO = R*(sqrt(C-N*ALPHA))/N
   m%xalbers(i) = RHO*DSIN(THETA*deg2rad)
   m%yalbers(i) = RHO0-RHO*DCOS(THETA*deg2rad)
end do
write(6,'("INFO: Finished generating Albers Equal Area Conic coordinates.")')
return
!-----------------------------------------------------------------------
END SUBROUTINE computeAlbersEqualAreaConic
!-----------------------------------------------------------------------

!-----------------------------------------------------------------------
!     S U B R O U T I N E   C O M P U T E  C P P
!-----------------------------------------------------------------------
!     jgf: Very short subroutine to compute the CPP projection,
!     allocating memory in the process, and not overwriting the
!     original lat/lon data.
!-----------------------------------------------------------------------
SUBROUTINE computeCPP(m)
IMPLICIT NONE
type(mesh_t), intent(inout) :: m  ! mesh to operate on
if (m%cppComputed.eqv..false.) then
   allocate(m%x_cpp(m%np),m%y_cpp(m%np))
   m%cppComputed = .true.
endif
write(6,'("INFO: Generating CPP coordinates.")')
m%x_cpp = R * (m%xyd(1,:)*deg2rad - m%slam0*deg2rad) * cos(m%sfea0*deg2rad)
m%y_cpp = m%xyd(2,:)*deg2rad * R
return
!-----------------------------------------------------------------------
END SUBROUTINE computeCPP
!-----------------------------------------------------------------------


!-----------------------------------------------------------------------
!     S U B R O U T I N E   C O M P U T E   2 X   A R E A S
!-----------------------------------------------------------------------
!     jgf: Compute 2x the elemental areas ... requires that the
!     the CPP projection has already been computed.
!-----------------------------------------------------------------------
SUBROUTINE compute2xAreas(m)
IMPLICIT NONE
type(mesh_t), intent(inout) :: m ! mesh to operate on
real(8) :: nx(3)
real(8) :: ny(3)
integer :: i, j
!
if (m%elementAreasComputed.eqv..true.) then
   return
endif
if (m%cppComputed.eqv..false.) then
   call computeCPP(m)
endif
allocate(m%areas(m%ne))
write(6,'("INFO: Computing 2x the elemental areas.")')
do i=1,m%ne
   do j=1,3
      nx(j) = m%x_cpp(m%nm(i,j))
      ny(j) = m%y_cpp(m%nm(i,j))
   end do
   m%areas(i)=(nx(1)-nx(3))*(ny(2)-ny(3))+(nx(3)-nx(2))*(ny(1)-ny(3))
end do
m%elementAreasComputed = .true.
write(6,'("INFO: Finished computing 2x the elemental areas.")')
!-----------------------------------------------------------------------
END SUBROUTINE compute2xAreas
!-----------------------------------------------------------------------

!-----------------------------------------------------------------------
!                    S U B R O U T I N E
!     C O M P U T E   W E I G H T I N G   C O E F F I C I E N T S
!-----------------------------------------------------------------------
!     jgf: Compute the solution weighting coefficients.
!-----------------------------------------------------------------------
SUBROUTINE computeWeightingCoefficients(m)
IMPLICIT NONE
type(mesh_t), intent(inout) :: m ! mesh to operate on
integer :: myNodes(0:4)
integer :: i, j
if (m%weightingCoefficientsComputed.eqv..true.) then
   return
endif
if (m%cppComputed.eqv..false.) then
   call computeCPP(m)
endif
allocate(m%sfac(m%np))
allocate(m%sfacAvg(m%ne))
allocate(m%fdx(3,m%ne))
allocate(m%fdy(3,m%ne))
m%sfac(:)=cos(m%sfea0*deg2rad)/cos(m%xyd(2,:)*deg2rad)
write(6,'("INFO: Computing weighting coefficients.")')
do i=1,m%ne
   myNodes(1:3) = m%nm(i,1:3)
   ! wrap the values around so we can easily implement a loop
   ! around the element
   myNodes(0) = myNodes(3)
   myNodes(4) = myNodes(1)
   m%sfacAvg(i) = oneThird * sum(m%sfac(myNodes(1:3)))
   ! loop over the nodes on this element
   do j=1,3
      m%fdy(j,i) = m%x_cpp(myNodes(j-1))-m%x_cpp(myNodes(j+1))         ! a1, a2, a3
      m%fdx(j,i) = ( m%y_cpp(myNodes(j+1))-m%y_cpp(myNodes(j-1)) ) * m%sFacAvg(i) ! b1, b2, b3
   end do
end do
m%weightingCoefficientsComputed = .true.
write(6,'("INFO: Finished computing weighting coefficients.")')
!-----------------------------------------------------------------------
      END SUBROUTINE computeWeightingCoefficients
!-----------------------------------------------------------------------

!-----------------------------------------------------------------------
!                     S U B R O U T I N E
!         C O M P U T E   E L E M E N T   C E N T R O I D S
!-----------------------------------------------------------------------
!     jgf: Compute the solution weighting coefficients.
!-----------------------------------------------------------------------
SUBROUTINE computeElementCentroids(m)
IMPLICIT NONE
type(mesh_t), intent(inout) :: m ! mesh to operate on
integer :: i
if (m%cppComputed.eqv..false.) then
   call computeCPP(m)
endif
allocate(m%centroids(2,m%ne))
write(6,'("INFO: Computing element centroids.")')
do i=1,m%ne
   m%centroids(1,i) = oneThird * sum(m%x_cpp(m%nm(i,1:3)))
   m%centroids(2,i) = oneThird * sum(m%y_cpp(m%nm(i,1:3)))
end do
write(6,'("INFO: Finished computing element centroids.")')
!-----------------------------------------------------------------------
      END SUBROUTINE computeElementCentroids
!-----------------------------------------------------------------------

!-----------------------------------------------------------------------
!                     S U B R O U T I N E
!         C O M P U T E   E L E M E N T   D E P T H S
!-----------------------------------------------------------------------
!     jgf: Compute the solution weighting coefficients.
!-----------------------------------------------------------------------
SUBROUTINE computeElementDepths(m)
IMPLICIT NONE
type(mesh_t), intent(inout) :: m ! mesh to operate on
real(8) :: x1, x2, x3 ! longitude temporary variables
real(8) :: y1, y2, y3 ! latitude temporary variables
real(8) :: w1, w2, w3 ! weighting coefficients of different nodes at the element centroid
real(8) :: TotalArea
integer :: e

if (m%elementDepthsComputed.eqv..true.) then
   return
endif

call computeElementCentroids(m)

allocate(m%eledepths(m%ne))
write(6,'("INFO: Computing element depths.")')
do e=1,m%ne
   X1 = m%x_cpp(m%nm(e,1))
   X2 = m%x_cpp(m%nm(e,2))
   X3 = m%x_cpp(m%nm(e,3))
   Y1 = m%y_cpp(m%nm(e,1))
   Y2 = m%y_cpp(m%nm(e,2))
   Y3 = m%y_cpp(m%nm(e,3))
   TotalArea = ABS((X2*Y3-X3*Y2)-(X1*Y3-X3*Y1)+(X1*Y2-X2*Y1))
   w1 = ( (m%centroids(1,e)-X3)*(Y2-Y3)+(X2-X3)*(Y3-m%centroids(2,e)) )/TotalArea
   w2 = ( (m%centroids(1,e)-X1)*(Y3-Y1)-(m%centroids(2,e)-Y1)*(X3-X1))/TotalArea
   w3 = (-(m%centroids(1,e)-X1)*(Y2-Y1)+(m%centroids(2,e)-Y1)*(X2-X1))/TotalArea
   m%eledepths(e) =                      &
      m%xyd(3,m%nm(e,1)) * w1 &
    + m%xyd(3,m%nm(e,2)) * w2 &
    + m%xyd(3,m%nm(e,3)) * w3
end do
m%elementDepthsComputed = .true.
write(6,'("INFO: Finished computing element depths.")')
!-----------------------------------------------------------------------
      END SUBROUTINE computeElementDepths
!-----------------------------------------------------------------------


!-----------------------------------------------------------------------
!  S U B R O U T I N E   C O M P U T E   S T A T I O N   W E I G H T S
!-----------------------------------------------------------------------
! jgf: Find the element in which a station is located and then compute
! the interpolation weights for evaluating the solution at the
! station location.
!-----------------------------------------------------------------------
subroutine computeStationWeights(station, m)
implicit none
type(station_t), intent(inout) :: station
type(mesh_t), intent(inout) :: m ! mesh to operate on (may compute element areas as a side effect)
!
real(8) :: x1, x2, x3 ! longitude temporary variables
real(8) :: y1, y2, y3 ! latitude temporary variables
real(8) :: subArea1, subArea2, subArea3, TotalArea
integer :: e

if (station%elementFound.eqv..false.) then

   do e=1,m%ne
      X1 = station%lon
      X2 = m%xyd(1,m%nm(e,2))
      X3 = m%xyd(1,m%nm(e,3))
      Y1 = station%lat
      Y2 = m%xyd(2,m%nm(e,2))
      Y3 = m%xyd(2,m%nm(E,3))
      SubArea1 = ABS((X2*Y3-X3*Y2)-(X1*Y3-X3*Y1)+(X1*Y2-X2*Y1))

      X1 = m%xyd(1,m%nm(e,1))
      X2 = station%lon
      X3 = m%xyd(1,m%nm(e,3))
      Y1 = m%xyd(2,m%nm(e,1))
      Y2 = station%lat
      Y3 = m%xyd(2,m%nm(e,3))
      SubArea2 = ABS((X2*Y3-X3*Y2)-(X1*Y3-X3*Y1)+(X1*Y2-X2*Y1))

      X1 = m%xyd(1,m%nm(e,1))
      X2 = m%xyd(1,m%nm(e,2))
      X3 = station%lon
      Y1 = m%xyd(2,m%nm(e,1))
      Y2 = m%xyd(2,m%nm(e,2))
      Y3 = station%lat
      SubArea3 = ABS((X2*Y3-X3*Y2)-(X1*Y3-X3*Y1)+(X1*Y2-X2*Y1))

      X1 = m%xyd(1,m%nm(e,1))
      X2 = m%xyd(1,m%nm(e,2))
      X3 = m%xyd(1,m%nm(e,3))
      Y1 = m%xyd(2,m%nm(e,1))
      Y2 = m%xyd(2,m%nm(e,2))
      Y3 = m%xyd(2,m%nm(e,3))
      TotalArea = ABS((X2*Y3-X3*Y2)-(X1*Y3-X3*Y1)+(X1*Y2-X2*Y1))

      if ((SubArea1+SubArea2+SubArea3).LE.(1.01*TotalArea))THEN
         station%elementIndex = e
         station%elementFound = .true.
         exit
      endif
   end do
endif

if (station%elementFound.eqv..true.) then
   X1 = m%xyd(1,m%nm(station%elementIndex,1))
   X2 = m%xyd(1,m%nm(station%elementIndex,2))
   X3 = m%xyd(1,m%nm(station%elementIndex,3))
   Y1 = m%xyd(2,m%nm(station%elementIndex,1))
   Y2 = m%xyd(2,m%nm(station%elementIndex,2))
   Y3 = m%xyd(2,m%nm(station%elementIndex,3))
   TotalArea = ABS((X2*Y3-X3*Y2)-(X1*Y3-X3*Y1)+(X1*Y2-X2*Y1))
   station%w(1) = ( (station%lon-X3)*(Y2-Y3)+(X2-X3)*(Y3-station%lat) )/TotalArea
   station%w(2) = ( (station%lon-X1)*(Y3-Y1)-(station%lat-Y1)*(X3-X1))/TotalArea
   station%w(3) = (-(station%lon-X1)*(Y2-Y1)+(station%lat-Y1)*(X2-X1))/TotalArea
   if (m%elementAreasComputed.eqv..false.) then
      call compute2xAreas(m)
   endif
   station%elementArea = 0.5d0*m%areas(e)
else
   station%elementIndex = 0
   station%elementArea = -99999.d0
   station%w = -99999.0
endif

!-----------------------------------------------------------------------
END SUBROUTINE computeStationWeights
!-----------------------------------------------------------------------

!-----+---------+---------+---------+---------+---------+---------+
   end module adcmesh
!-----+---------+---------+---------+---------+---------+---------+
