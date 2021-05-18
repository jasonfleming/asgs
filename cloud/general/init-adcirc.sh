#!/usr/bin/env bash

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

# Note:
# If an operator wishes to use the ssh form of the git url, they will need
# to update the environmental variable ADCIRC_GIT_URL to use the url,
#    
#   export ADCIRC_GIT_URL=git@github.com:adcirc
#
# before running 'initadcirc' in asgsh
#

if [ "${1}" = "clean" ]; then
  echo "'clean' not implemented for optional ADCIRC/SWAN step at this time, clean up for ADCIRC and SWAN must be done manually."
  exit 0
fi

ADCIRCS=(
"v53release"
"v53release-qbc"
"v53release-gfortran-10"
"v53release-testsuite"
"v53release-adcircpolate"
"v55release"
"v55release-qbc"
"v55release-swan-gfortran"
"v55release-swan-gfortran-10"
)
NUM_ADC=${#ADCIRCS[@]}

_show_supported_versions()
{
  echo  '                                              ||ASGS Supported ADCIRC versions||'
  echo  '/~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\'
  echo  '|1. v53release                 | standard version traditionally used           |'
  echo  '|2. v53release-qbc             | v53 with makefile support for LONIs qbc       |'
  echo  '|3. v53release-gfortran-10     | v53 with makefile support for gfortran 10     |'
  echo  '|4. v53release-testsuite       | v53 with tools supporting testsuite           |'
  echo  '|5. v53release-adcircpolate    | v53 with required ADCIRCpolate support        |'
  echo  '|6. v55release                 | standard version + build support for LONIs qbc|'
  echo  '|7. v55release-swan-gfortran   | v55release with gfortran default for swan     |'
  echo  '|8. v55release-swan-gfortran-10| v55release with gfortran 10 default for swan  |'
  echo  '\~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~/'
  echo
  if [ "${1}" != "noexit" ]; then
    # exits on error if '1' is optionally passed, defaults to 0 (no error)
    exit ${1:-0} 
  fi
}

_is_a_num()
{
  re='[1-9][0-9]?$'
  if [[ "${1}" =~ $re ]] ; then
    echo -n $1 
  else
    echo -n -1 
  fi
  return
}

if [ "${1}" = "supported" ]; then
  _show_supported_versions
fi

# preconditions
if [ -z "$ADCIRC_META_DIR" ]; then
  echo "ADCIRC_META_DIR is not set. Run interactively through asgsh or automatically via asgs-brew.pl."
  echo
  echo "Please note that this tool is meant to be run within an ASGS environment and is not supported "
  echo "as a general purpose too. Per the license of the code, however, anyone is free to adapt it.   "
  echo
  exit 1
fi

INTERACTIVE=
if [ -n "$_ASGSH_PID" ]; then
  # indicates further down to interactively guide user through (in asgsh env)
  # the building of ADCIRC, otherwise it does things automatically
  # assuming the required environment is provided through asgs-brew.pl

  INTERACTIVE=yes
fi

# Ask user for preferences, but offer defaults in the present in the asgsh environment
if [ "$INTERACTIVE" == "yes" ]; then
  _show_supported_versions noexit 
  # get branch/tag/sha to checkout
  __ADCIRC_GIT_BRANCH=${ADCIRCS[0]} # current preferred default
  read -p "What supported 'version' of the ADCIRC source do you wish to build (by name or select 1-${NUM_ADC})? [$__ADCIRC_GIT_BRANCH] " _ADCIRC_GIT_BRANCH

  #
#   # Handles selection by number
  #
  if [ -n "$_ADCIRC_GIT_BRANCH" ]; then
    echo
    # check for number selection
    _isnum=$(_is_a_num $_ADCIRC_GIT_BRANCH)
    if [ $_isnum -gt -1 ]; then
      _ADCIRC_GIT_BRANCH=${ADCIRCS[$(($_isnum-1))]} # zero indexed
      if [ -z "$_ADCIRC_GIT_BRANCH" ]; then
        echo "(fatal) invalid value..."
        echo
        exit 1
      else
        echo "(info) Selection: '$_ADCIRC_GIT_BRANCH'"
      fi
    fi
    # do not export, don't affect current environment after build
    ADCIRC_GIT_BRANCH=$_ADCIRC_GIT_BRANCH
  else
    ADCIRC_GIT_BRANCH=$__ADCIRC_GIT_BRANCH
  fi

# First pass check
  __ADCIRC_PATCHSET_BASE=${SCRIPTDIR}/patches/ADCIRC
  PATCHSET_NAME=
  PATCHSET_DIR=
  case "${ADCIRC_GIT_BRANCH}" in
    v53release|v54release)
      #noop - branches exist "upstream"
      ;;
    v53release-gfortran-10)
      PATCHSET_NAME="v53release-gfortran-10"
      PATCHSET_DIR=${__ADCIRC_PATCHSET_BASE}/${PATCHSET_NAME}
      # update to proper base branch
      ADCIRC_GIT_BRANCH=v53release
      ;;
    v53release-qbc)
      PATCHSET_NAME="v53release-qbc"
      PATCHSET_DIR=${__ADCIRC_PATCHSET_BASE}/${PATCHSET_NAME}
      # update to proper base branch
      ADCIRC_GIT_BRANCH=v53release
      ;;
    v53release-adcircpolate)
      PATCHSET_NAME="v53release-adcircpolate"
      PATCHSET_DIR=${__ADCIRC_PATCHSET_BASE}/${PATCHSET_NAME}
      # update to proper base branch
      ADCIRC_GIT_BRANCH=v53release
      ;;
    v53release-testsuite)
      PATCHSET_NAME="v53release-testsuite"
      PATCHSET_DIR=${__ADCIRC_PATCHSET_BASE}/${PATCHSET_NAME}
      # update to proper base branch
      ADCIRC_GIT_BRANCH=v53release
      ;;
    v55release)
      PATCHSET_NAME="v55release"
      PATCHSET_DIR=${__ADCIRC_PATCHSET_BASE}/${PATCHSET_NAME}
      # update to proper base branch
      ADCIRC_GIT_BRANCH=92ccdb974b7fb150 # v55release
      ;;
    v55release-swan-gfortran)
      PATCHSET_NAME="v55release-swan-gfortran"
      PATCHSET_DIR=${__ADCIRC_PATCHSET_BASE}/${PATCHSET_NAME}
      # update to proper base branch
      ADCIRC_GIT_BRANCH=92ccdb974b7fb150 # v55release
      ;;
    v55release-swan-gfortran-10)
      PATCHSET_NAME="v55release-swan-gfortran-10"
      PATCHSET_DIR=${__ADCIRC_PATCHSET_BASE}/${PATCHSET_NAME}
      # update to proper base branch
      ADCIRC_GIT_BRANCH=92ccdb974b7fb150 # v55release
      ;;
    *)
      echo "ADCIRC 'version' '${ADCIRC_GIT_BRANCH}' is not officially supported at this time."
      exit 1
  esac

  echo
  # determine what to name the ADCIRC profile
  if [ -n "$PATCHSET_NAME" ]; then
    __ADCIRC_PROFILE_NAME=${PATCHSET_NAME}-${ADCIRC_COMPILER}
  else
    __ADCIRC_PROFILE_NAME=${ADCIRC_GIT_BRANCH}-${ADCIRC_COMPILER}
  fi
  read -p "What would you like to name this ADCIRC build profile? [$__ADCIRC_PROFILE_NAME] " _ADCIRC_PROFILE_NAME
  if [ -n "$_ADCIRC_PROFILE_NAME" ]; then
    ADCIRC_PROFILE_NAME=$_ADCIRC_PROFILE_NAME
  else
    ADCIRC_PROFILE_NAME=$__ADCIRC_PROFILE_NAME
  fi
  echo

  # determine where to look for source directory or checkout git repo for the build
  if [ -e "$WORK" ]; then
    __ADCIRCBASE=${WORK}/adcirc-cg-${ADCIRC_PROFILE_NAME}
  else
    __ADCIRCBASE=${ASGS_HOME}/adcirc-cg-${ADCIRC_PROFILE_NAME}
  fi
  read -p "In what directory would you like to build ADCIRC? [${__ADCIRCBASE}] " _ADCIRCBASE
  if [ -n "${_ADCIRCBASE}" ]; then
    ADCIRCBASE=$_ADCIRCBASE
  else
    ADCIRCBASE=$__ADCIRCBASE
  fi
  echo
fi

  ADCIRCDIR=${ADCIRCBASE}/work
  # deal with SWAN coupling build based on supported ADCIRC branches (versions):
  # and potential patching of ADCIRC or SWAN
  __ADCIRC_PATCHSET_BASE=${SCRIPTDIR}/patches/ADCIRC
  case "${ADCIRC_GIT_BRANCH}" in
    v53release|v53release-qbc|v53release-gfortran-10|v53release-adcircpolate)
      SWANDIR=${ADCIRCBASE}/swan
      ;;
    v54release)
      SWANDIR=${ADCIRCBASE}/swan
      ;;
    v55release|v55release-swan-gfortran|v55release-swan-gfortran-10|92ccdb974b7fb150)
      # Note v55release = sha256:92ccdb974b7fb150bb42b2536fce4d8c0bcee726
      SWANDIR=${ADCIRCBASE}/thirdparty/swan
      ;;   
    *)
      echo Branch \"${ADCIRC_GIT_BRANCH}\" is not officially supported at this time. 
      exit 1
  esac

# meant to be run under the asgs-brew.pl environment
# looks for:
# ASGS_MACHINE_NAME - passed to MACHINENAME of ADCIRC's Makefile, internally determines compiler flags and some library paths
# NETCDFHOME        - tells ADCIRC where to look for NetCDF libraries
# ADCIRCBASE        - main directory containing ADCIRC source code
# ADCIRC_COMPILER   - "intel" or "gfortran", set via --compiler in asgs-brew.pl
# ADCIRC_GIT_BRANCH - passed to `git checkout`, set via --adcirc-git-branch in asgs-brew.pl
# ADCIRC_GIT_URL    - git repo remote URL, set via --adcirc-git-remote in asgs-brew.pl
# ADCIRC_GIT_REPO   - git repository (likely 'adcirc-cg')

# first class ADCIRC related binaries
ADCIRC_BINS="padcirc adcirc adcprep hstime aswip"
ADCIRC_MAKE_CMD="make $ADCIRC_BINS compiler=${ADCIRC_COMPILER} NETCDF=enable NETCDF4=enable NETCDF4_COMPRESSION=enable NETCDFHOME=${NETCDFHOME} NETCDFROOT=${NETCDFROOT} MACHINENAME=${ASGS_MACHINE_NAME}"

# for building coupled adcswan/padcswan (no netCDF)
ADCSWAN_BINS="adcswan padcswan"
ADCSWAN_MAKE_CMD="make $ADCSWAN_BINS SWAN=enable compiler=${ADCIRC_COMPILER} MACHINENAME=${ASGS_MACHINE_NAME}"

# SWAN related utilities other than adcswan/padcswan
SWAN_UTIL_BINS="unhcat.exe"
SWAN_UTIL_BINS_MAKE_CMD="make unhcat compiler=${ADCIRC_COMPILER} NETCDF=enable NETCDF4=enable NETCDF4_COMPRESSION=enable NETCDFHOME=${NETCDFHOME} NETCDFROOT=${NETCDFROOT} MACHINENAME=${ASGS_MACHINE_NAME}"

if [ ! -d ${ADCIRCBASE} ]; then
  if [ "$INTERACTIVE" == "yes" ]; then
    _answer=yes
    read -p "Create directory, '$ADCIRCBASE'? [$_answer] " answer
    if [ -z "$answer" ]; then
      answer=$_answer
    fi
    if [ "$answer" != 'yes' ]; then
      echo '(fatal) no directory was created. Exiting install.'
      exit
    fi
    echo
  fi
  mkdir -p ${ADCIRCBASE} 2> /dev/null
else
  echo Found directory, ${ADCIRCBASE}
  echo
fi
if [ ! -d ${ADCIRCBASE}/.git ]; then
  if [ "$INTERACTIVE" == "yes" ]; then
    _answer=yes
    read -p "Download ADCIRC git repository from GitHub? [$_answer] " answer
    if [ -z "$answer" ]; then
      answer=$_answer
    fi
    if [ "$answer" != 'no' ]; then
      echo
      git clone ${ADCIRC_GIT_URL}/${ADCIRC_GIT_REPO}.git ${ADCIRCBASE}
    fi
  fi
else
  echo "$ADCIRCBASE appears to already contain a git repository."
fi

# current branch management is naive and assumes that the branch
# requested is available locally (via origin or any other manually
# added remotes (see, git remote --help for more information)
if [ ! -d "$ADCIRCBASE" ]; then
  echo "(fatal) $ADCIRCBASE not found. Exiting install."
  exit 1
else
  cd ${ADCIRCBASE}
fi

# only try to checkout branch/tag/SHA if it's a git directory (looks for .git)

if [ -d "$ADCIRCBASE/.git" ]; then
  if [ "$INTERACTIVE" == "yes" ]; then
    echo
    read -p "Which ADCIRC branch would you like to checkout from GitHub ('.' to skip checkout)? [$ADCIRC_GIT_BRANCH] " repo
    if [ -z "$repo" ]; then
      repo=$ADCIRC_GIT_BRANCH
    fi
    do_checkout=yes
    if [ "$repo" == "." ]; then
      do_checkout=no
    fi
    echo
  fi
  if [ "$do_checkout" == "yes" ]; then
    CURRENT_BRANCH=$(git branch | egrep '^\*' | awk '{ print $2 }')
    if [ "${ADCIRC_GIT_BRANCH}" != "${CURRENT_BRANCH}" ]; then
      git config advice.detachedHead=false
      git -c advice.detachedHead=false checkout ${ADCIRC_GIT_BRANCH}
      EXIT=$?
      if [ $EXIT -gt 0 ]; then
        echo "(fatal) error checking out git repository. Exiting ($EXIT)."
        exit $EXIT
      fi
    fi
  fi
fi

# final check to make sure it looks like the expected ADCIRC source
if [ ! -d "$ADCIRCDIR" ]; then
  echo "(fatal) $ADCIRCDIR is missing the './work' directory. Exiting install."
  exit 1
fi

# ~ A P P L Y  P A T C H S E T ~
#
# Notes:
# 1. Fails if patchset is define, but directory doesn't exit
# 2. Informs and skips patching if patches have already been applied
# 3. Adding a patch set is not too difficult, but is not done here; look "up"
#
PTOUCH="$(pwd)/${ADCIRC_GIT_BRANCH}-applied.out"
if [ -n "${PATCHSET_DIR}" ]; then
  if [ -e "${PTOUCH}" ]; then
    echo "(info) patches already applied, skipping ..."
  else
    if [ ! -d "${PATCHSET_DIR}" ]; then
      echo "(fatal) patch set directory not found. Exiting."
      exit 1
    fi
    echo
    echo applying patches from $PATCHSET_DIR ...
    # apply from perspective of $ADCIRCBASE, since it's possible we could also
    # be patching in a third party directory
    pCOUNT=1
    for diff in $(find ${PATCHSET_DIR} -type f  | sort -n); do
      printf "patch %02d - applying %s\n" $pCOUNT $diff
      OUT=$(patch -p1 < $diff 2>&1)
      EXIT=$?
      if [ $EXIT -gt 0 ]; then
        echo $OUT
        echo "(fatal) error applying patch: $diff"
        echo Exiting.
        exit $EXIT
      fi
      _app_date=$(date "+%D %T %Z")
      echo "$_app_date $diff" >> $PTOUCH
      pCOUNT=$((pCOUNT+1))
    done
  fi
fi

if [ "$INTERACTIVE" = "yes" ]; then
  answer=
  echo
  echo "About to build ADCIRC in $ADCIRCDIR with the following command:"
  echo
  echo "cd $SWANDIR && \\"
  echo "   $SWAN_UTIL_BINS_MAKE_CMD && \\"
  echo "cd $ADCIRCDIR && \\"
  echo "   $ADCIRC_MAKE_CMD && \\"
  echo "   $ADCSWAN_MAKE_CMD"
  echo
  _answer=yes
  read -p "Proceed to build? [$_answer] " answer
  echo
  if [ -z "$answer" ]; then
    answer=$_answer
  fi
  if [ "$answer" != 'yes' ]; then
    echo "build stopped. Exiting."
    exit 1
  fi
fi

# attempt to build
cd $SWANDIR          && \
$SWAN_UTIL_BINS_MAKE_CMD && \
cd $ADCIRCDIR        && \
$ADCIRC_MAKE_CMD     && \
$ADCSWAN_MAKE_CMD

# catch failed exit status, for both interactive and initial asgs-brew.pl build
EXIT=$?
if [ $EXIT -gt 0 ]; then
  echo "build failed ($EXIT)"
  exit $EXIT
fi

# create directory to track ADCIRC installations
mkdir -p $ADCIRC_META_DIR 2> /dev/null

# set default if not set
ADCIRC_META_FILE=$ADCIRC_META_DIR/$ADCIRC_PROFILE_NAME
echo 'export ASGS_HOME='$ASGS_HOME                               >  $ADCIRC_META_FILE
echo 'export ASGS_MACHINE_NAME='$ASGS_MACHINE_NAME               >> $ADCIRC_META_FILE
echo 'export NETCDFHOME='$NETCDFHOME                             >> $ADCIRC_META_FILE
echo 'export ADCIRCBASE='$ADCIRCBASE                             >> $ADCIRC_META_FILE
echo 'export ADCIRCDIR='$ADCIRCDIR                               >> $ADCIRC_META_FILE
echo "export SWANDIR='$SWANDIR'"                                 >> $ADCIRC_META_FILE
echo 'export ADCIRC_COMPILER='$ADCIRC_COMPILER                   >> $ADCIRC_META_FILE
echo 'export ADCIRC_GIT_BRANCH='$ADCIRC_GIT_BRANCH               >> $ADCIRC_META_FILE
echo 'export ADCIRC_GIT_URL='$ADCIRC_GIT_URL                     >> $ADCIRC_META_FILE
echo 'export ADCIRC_GIT_REPO='$ADCIRC_GIT_REPO                   >> $ADCIRC_META_FILE
echo 'export ASGS_MAKEJOBS='$ASGS_MAKEJOBS                       >> $ADCIRC_META_FILE
echo "export ADCIRC_MAKE_CMD='$ADCIRC_MAKE_CMD'"                 >> $ADCIRC_META_FILE
echo "export SWAN_UTIL_BINS_MAKE_CMD='$SWAN_UTIL_BINS_MAKE_CMD'" >> $ADCIRC_META_FILE
echo "export ADCSWAN_MAKE_CMD='$ADCSWAN_MAKE_CMD'"               >> $ADCIRC_META_FILE
echo "export ADCIRC_PROFILE_NAME=$ADCIRC_PROFILE_NAME"           >> $ADCIRC_META_FILE
echo "export ADCIRC_BINS='$ADCIRC_BINS'"                         >> $ADCIRC_META_FILE
echo "export ADCSWAN_BINS='$ADCSWAN_BINS'"                       >> $ADCIRC_META_FILE
echo "export SWAN_UTIL_BINS='$SWAN_UTIL_BINS'"                   >> $ADCIRC_META_FILE

if [ "$INTERACTIVE" == "yes" ]; then
  echo
  echo ADCIRC has been build and the ADCIRC profile registered in asgsh.
  echo To load this profile, at the asgsh prompt, enter:
  echo
  echo   load adcirc $ADCIRC_PROFILE_NAME
  echo
  echo "Once loaded, save the current asgsh profile using the the 'save' command."
  echo
fi
