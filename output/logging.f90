!--------------------------------------------------------------------------
! logging.f90
!--------------------------------------------------------------------------
!
! A module for writing log messages from fortran utility programs.
!
!--------------------------------------------------------------------------
! Copyright(C) 2017 Jason Fleming
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
module logging
!
character(len=2048) :: logSource ! name of program doing the logging
!
! log file name, defaults to the name of the fortran program doing the
! writing appended with ".log"
character(len=2048) :: logFileName
integer :: loglun ! log file i/o unit number
logical :: loggingInitialized = .false. ! true if log files set up and logfile opened
!
! numbers representing log levels from least to most severe
integer, parameter :: DEBUG = -1
integer, parameter :: ECHO = 0
integer, parameter :: INFO = 1
integer, parameter :: WARNING = 2
integer, parameter :: ERROR = 3
!
! severity of messages to write to log file (this level and higher)
integer :: logLevel = INFO
!
! to hold character representation of logging levels
character(len=10) :: logLevelNames(-1:3)
!
character(len=2048) :: scratchMessage ! for forming log messages


contains

!--------------------------------------------------------------------
!     S U B R O U T I N E    S E T   L O G G I N G   L E V E L
!--------------------------------------------------------------------
! Set the level of severity for messages to be logged; log messages
! with a lower severity will be silently ignored.
!--------------------------------------------------------------------
subroutine setLoggingLevel(lvl)
implicit none
character(len=20), intent(in) :: lvl ! message severity
if (loggingInitialized.eqv..false.) then
   write(6,*) 'ERROR: Must call subroutine initLogging before using logging module.'
   stop
endif
select case(trim(lvl))
case('DEBUG','Debug','DeBug','debug')
   logLevel = DEBUG
case('ECHO','Echo','echo')
   logLevel = ECHO
case('INFO','Info','info')
   logLevel = INFO
case('WARNING','Warning','warning')
   logLevel = WARNING
case('ERROR','Error','error')
   logLevel = ERROR
case default
   write(scratchMessage,'("Could not set logging level to ",a,".")') trim(lvl)
   call allMessage(ERROR,scratchMessage)
   stop
end select
!--------------------------------------------------------------------
end subroutine setLoggingLevel
!--------------------------------------------------------------------

!--------------------------------------------------------------------
!     S U B R O U T I N E    I N I T   L O G G I N G
!--------------------------------------------------------------------
!  Initialize the names for the logging levels and the counter
!  for the current subroutine.
!--------------------------------------------------------------------
subroutine initLogging(lun, progname,logname)
implicit none
character(*), intent(in) :: progname ! name of program writing log messages
character(*), intent(in), optional :: logname ! to override default log name
integer :: lun ! i/o unit for log file, calling routine should use function availableUnitNumber to set this
integer :: errorIO ! positive if there was an i/o error; zero otherwise
logLevelNames(-1) = "DEBUG"
logLevelNames(0) = "ECHO"
logLevelNames(1) = "INFO"
logLevelNames(2) = "WARNING"
logLevelNames(3) = "ERROR"
logSource = trim(adjustl(progname))
if (present(logname)) then
   logFileName = trim(adjustl(logName))
else
   logFileName = trim(adjustl(logSource)) // '.log'
endif
! open the log file
loglun = lun
open(unit=loglun,file=trim(adjustl(logFileName)),action='write',status='replace',iostat=errorIO)
if (errorIO.gt.0) then
   write(6,'(a)') 'ERROR: Could not open log file for writing.'
   stop
endif
loggingInitialized = .true.
!--------------------------------------------------------------------
end subroutine initLogging
!--------------------------------------------------------------------

!--------------------------------------------------------------------
!     S U B R O U T I N E    S T D O U T
!--------------------------------------------------------------------
!  Writes a log message to stdout (i.e., screen or console).
!--------------------------------------------------------------------
subroutine stdout(level, message)
implicit none
integer, intent(in) :: level
character(*), intent(in) :: message
!
!if (loggingInitialized.eqv..false.) then
!   write(6,*) 'ERROR: Must call subroutine initLogging before using logging module.'
!   stop
!endif
if (level.ge.logLevel) then
   write(6,'(a,": ",a,": ",a)') trim(logLevelNames(level)),trim(adjustl(logSource)),trim(message)
endif
!--------------------------------------------------------------------
end subroutine stdout
!--------------------------------------------------------------------

!--------------------------------------------------------------------
!     S U B R O U T I N E    L O G   M E S S A G E
!--------------------------------------------------------------------
!  Writes a log message to log file.
!--------------------------------------------------------------------
subroutine logMessage(level, message)
implicit none
integer, intent(in) :: level
character(*), intent(in) :: message
!
!if (loggingInitialized.eqv..false.) then
!   write(6,*) 'ERROR: Must call subroutine initLogging before using logging module.'
!   stop
!endif
if (level.ge.logLevel) then
   write(loglun,'(a,": ",a,": ",a)') trim(logLevelNames(level)),trim(adjustl(logSource)),trim(message)
endif
!--------------------------------------------------------------------
end subroutine logMessage
!--------------------------------------------------------------------


!--------------------------------------------------------------------
!     S U B R O U T I N E   A L L    M E S S A G E
!--------------------------------------------------------------------
!   Writes a message to log file and to the screen.
!--------------------------------------------------------------------
subroutine allMessage(level, message)
implicit none
integer, intent(in) :: level
character(*), intent(in) :: message
!if (loggingInitialized.eqv..false.) then
!   write(6,*) 'ERROR: Must call subroutine initLogging before using logging module.'
!   stop
!endif
call stdout(level, message)
call logMessage(level, message)
!--------------------------------------------------------------------
end subroutine allMessage
!--------------------------------------------------------------------

!--------------------------------------------------------------------
!--------------------------------------------------------------------
end module logging
!--------------------------------------------------------------------
!--------------------------------------------------------------------
!
!
!
!--------------------------------------------------------------------
!--------------------------------------------------------------------
!                 M O D U L E   I O U T I L
!--------------------------------------------------------------------
!--------------------------------------------------------------------
! A module that provides sundry helper subroutines and functions for
! files. for opening and reading
!--------------------------------------------------------------------
! Copyright(C) 2017 Jason Fleming
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
module ioutil
!--------------------------------------------------------------------------
!--------------------------------------------------------------------------
use netcdf
implicit none
!
integer :: argcount
character(1024) :: cmdlineopt
character(1024) :: cmdlinearg
integer, parameter :: minUnitNumber = 10 ! lowest fortran i/o unit number
integer, parameter :: maxUnitNumber = 999 ! highest fortran i/o unit number
!
! file format integers
integer, parameter :: OFF = 0
integer, parameter :: ASCII = 1     ! ADCIRC ASCII
integer, parameter :: SPARSE_ASCII = 4  ! ADCIRC sparse ASCII
integer, parameter :: NETCDF3 = 3
integer, parameter :: NETCDF4 = 5
integer, parameter :: XDMF = 7
integer, parameter :: NETCDFG = 35  ! either NETCDF3 or NETCDF4
integer, parameter :: ASCIIG = 14   ! either ASCII or SPARSE_ASCII
!
! file category integers
integer, parameter :: UNKNOWN = -1
integer, parameter :: MESH = 0     ! fort.14
integer, parameter :: STATION = 1  ! fort.61, fort.72, etc
integer, parameter :: DOMAIN = 2   ! fort.63, fort.64, fort.73, fort.74, etc
integer, parameter :: HOTSTART = 3 ! fort.67, fort.68 (2D)
integer, parameter :: NODALATTRIBF = 4 ! fort.13
integer, parameter :: INITRIVER = 5 ! fort.88
integer, parameter :: MINMAX = 6    ! maxele.63, maxwvel.63, etc
integer, parameter :: OWI = 7       ! fort.221, fort.222, fort.223, fort.224
integer, parameter :: ESLNODES = 8 ! ESLNodes.63
integer, parameter :: MAUREPT = 108 ! output from maureparticle

!-----------
!-----------
contains
!-----------
!-----------
!-----------------------------------------------------------------------
!     S U B R O U T I N E   O P E N  F I L E  F O R  R E A D
!-----------------------------------------------------------------------
!     jgf: Added general subroutine for opening an existing
!     file for reading. Includes error checking.
!-----------------------------------------------------------------------
subroutine openFileForRead(lun, filename, errorIO)
use logging
implicit none
integer, intent(in) :: lun   ! fortran logical unit number
character(*), intent(in) :: filename ! full pathname of file
integer, intent(out) :: errorIO
logical unitConnected !.true. if this lun is already being used
!
!  Check to see if file exists
call checkFileExistence(filename, errorIO)
if (errorIO.ne.0) then
   return
endif
!
! Check to see if the unit number is already in use
inquire(unit=lun,opened=unitConnected)
if (unitConnected.eqv..true.) then
   write(scratchMessage,'("The i/o unit ",i0," is already connected.")') lun
   call allMessage(ERROR,scratchMessage)
   errorIO = 1
   return
endif
!
! Open existing file
OPEN(lun,FILE=trim(filename),STATUS='OLD',ACTION='READ',IOSTAT=errorIO)
if (errorIO.ne.0) then
   write(scratchMessage,'("Could not open the file ",A,".")') trim(filename)
   call allMessage(ERROR,scratchMessage)
else
   write(scratchMessage,'("The file ",A," was opened successfully.")') trim(filename)
   call allMessage(INFO,scratchMessage)
endif
return
!-----------------------------------------------------------------------
   END SUBROUTINE openFileForRead
!-----------------------------------------------------------------------

!----------------------------------------------------------------------
!           S U B R O U T I N E    D O W N C A S E
!----------------------------------------------------------------------
! @jasonfleming: return a downcased version of the input string
!----------------------------------------------------------------------
subroutine downcase(string)
implicit none
character(*), intent(inout) :: string ! character array to downcase
integer :: asciiCode ! decimal ascii code for a particular character
integer :: i ! character counter
!
! go through the character array looking for ascii codes between
! 65 (uppercase A) and 90 (uppercase Z); replace these characters
! with lowercase
do i=1,len_trim(string)
   asciiCode = ichar(string(i:i))
   ! modify uppercase alphabetic characters only
   if ((asciiCode.ge.65).and.(asciiCode.le.90)) then
      asciiCode = asciiCode + 32
      string(i:i) = char(asciiCode)
   endif
end do
!----------------------------------------------------------------------
end subroutine downcase
!----------------------------------------------------------------------

!-----------------------------------------------------------------------
! S U B R O U T I N E   F I N D   U N U S E D   U N I T   N U M B E R
!-----------------------------------------------------------------------
! Dynamic unit numbers prevent collisions.
!-----------------------------------------------------------------------
integer function availableUnitNumber()
implicit none
logical :: unusedUnitNumberFound ! .true. if an unused unit number is available
logical :: isOpen ! true if an i/o unit number is connected to an open file
integer :: errorIO

do availableUnitNumber = minUnitNumber,maxUnitNumber
   inquire(unit=availableUnitNumber,opened=isOpen,iostat=errorIO)
   if (errorIO.eq.0) then
      if (isOpen.eqv..true.) then
         cycle
      else
         unusedUnitNumberFound = .true.
         exit
      endif
   else
      ! an error occurred
      write(6,'("ERROR: Could not determine which i/o unit numbers are unused. The Fortran i/o error code was ",i0,".")') errorIO
      stop
   endif
end do
if (unusedUnitNumberFound.eqv..false.) then
   write(6,'("ERROR: Could not find an unused unit number.")')
   stop
endif
!-----------------------------------------------------------------------
end function availableUnitNumber
!-----------------------------------------------------------------------

!-----------------------------------------------------------------------
!     S U B R O U T I N E   C H E C K   F I L E   E X I S T E N C E
!-----------------------------------------------------------------------
!     jgf: Just check for the existence of a file. I separated this
!     from openFileForRead so that I could use it on NetCDF files
!     as well.
!-----------------------------------------------------------------------
subroutine checkFileExistence(filename, errorIO)
use logging
implicit none
character(*), intent(in) :: filename ! full pathname of file
integer, intent(out) :: errorIO
logical :: fileFound    ! .true. if the file is present

!
! Check to see if file exists
write(scratchMessage,'("Searching for file ",a," ...")') trim(filename)
call allMessage(INFO,scratchMessage)
inquire(file=trim(filename),exist=fileFound,iostat=errorIO)
if (fileFound.eqv..false.) then
   write(scratchMessage,'("The file ",A," was not found.")') trim(filename)
   call allMessage(ERROR,scratchMessage)
else
   write(scratchMessage,'("The file ",A," was found.")') trim(filename)
   call allMessage(INFO,scratchMessage)
endif
!-----------------------------------------------------------------------
   END SUBROUTINE checkFileExistence
!-----------------------------------------------------------------------

!----------------------------------------------------------------------
!                  F U N C T I O N     I N D
!----------------------------------------------------------------------
! returns a format string containing the right number of spaces for the
! specified indentation level
!----------------------------------------------------------------------
function ind(change)
implicit none
character(len=1), intent(in) :: change
character(len=4) :: ind
integer, save :: currentIndent = 0
!
select case(change)
case('+') ! increase indentation level
   currentIndent = currentIndent + 3
case('-') ! decrease indentation level
   currentIndent = currentIndent - 3
case default
   ! keep indentation level the same
end select
if ( currentIndent.eq.0 ) then
   ind="1p"  ! gfortran does not like "0x" and claims it needs a p descriptor
else
   write(ind,'(i3,"x")') currentIndent
endif
!----------------------------------------------------------------------
end function ind
!----------------------------------------------------------------------

!----------------------------------------------------------------------
!  CHECK
!---------------------------------------------------------------------
subroutine check(ncstatus)
use netcdf
#ifdef INTEL
! See ASGS Issue-393
use ifcore, Only : tracebackqq
#endif
implicit none
integer,intent(in) :: ncstatus
real(8), allocatable :: intentionalSegFault(:)
real(8) :: triggerSegFaultIntentionallyForStackTrace
if(ncstatus.ne.nf90_noerr)then
   write(*,'(a,a)') "ERROR: ",trim(nf90_strerror(ncstatus))
#ifdef INTEL
    ! See ASGS Issue-393
    ! https://stackoverflow.com/questions/65157007/tracebackqq-with-ifort-leads-to-segmentation-fault
    ! Note: "user_exit_code = -1" is required to match default behavior of the
    ! original "backtrace" call that is now used for all non-INTEL compilers
    call tracebackqq( user_exit_code = -1 )
#endif
#ifndef INTEL
    ! See ASGS Issue-393
    ! https://gcc.gnu.org/onlinedocs/gfortran/BACKTRACE.html
    ! Note: used in this form, "backtrace" doesn't halt execution (unchanged
    ! from origial code)
    call backtrace
#endif
   triggerSegFaultIntentionallyForStackTrace = intentionalSegFault(1)
   stop 1
endif
!---------------------------------------------------------------------
end subroutine check
!---------------------------------------------------------------------


!----------------------------------------------------------------------
!----------------------------------------------------------------------
end module ioutil
!----------------------------------------------------------------------
!----------------------------------------------------------------------


