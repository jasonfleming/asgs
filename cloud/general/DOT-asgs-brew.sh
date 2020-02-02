#!/usr/bin/env bash
# xxx DO NOT CUSTOMIZE THIS FILE, IT WILL BE OVERWRITTEN NEXT TIME asgs-brew.pl IS RUN xxx
# xxx THIS FILE IS GENERATED BY asgs-brew.pl                                           xxx
# xxx DO NOT CUSTOMIZE THIS FILE, IT WILL BE OVERWRITTEN NEXT TIME asgs-brew.pl IS RUN xxx
export PS1='asgs (none)>'
echo
echo "Quick start:"
echo "  'help' for full list of options and features"
echo "  'list profiles' to see what scenario package profiles exist"
echo "  'load <profile_name>' to load saved profile"
echo "  'run' to initiated ASGS for loaded profile"
echo "  'exit' to return to the login shell"
echo
echo "NOTE: This is a fully function bash shell environment; to update asgsh"
echo "or to recreate it, exit this shell and run asgs-brew.pl with the"
echo " --update-shell option"
echo

# xxx DO NOT CUSTOMIZE THIS FILE, IT WILL BE OVERWRITTEN NEXT TIME asgs-brew.pl IS RUN xxx
# xxx THIS FILE IS GENERATED BY asgs-brew.pl                                           xxx
# xxx DO NOT CUSTOMIZE THIS FILE, IT WILL BE OVERWRITTEN NEXT TIME asgs-brew.pl IS RUN xxx

# COMMANDS DEFINED AS BASH FUNCTIONS

help() {
  echo
  echo Commands:
  echo "   show   <param>             - shows specified profile variables (i.e., variables that do not last after 'exit')"
  echo "       *  config              - shows ASGS configuration file used by 'run', (\$ASGS_CONFIG)"
  echo "       *  editor              - shows what default editor is set to, (\$EDITOR)"
  echo "       *  instancename        - shows ASGS instance name that is derived from a valid config file, (\$INSTANCENAME)"
  echo "       *  propertiesfile      - shows ASGS 'run.properties' file location, derived from rundir; (\$PROPERTIESFILE)"  
  echo "       *  rundir              - shows ASGS rundir location, read directly from a valid state file, (\$RUNDIR)"
  echo "       *  scratchdir          - shows ASGS main script directory used by all underlying scripts, (\$SCRATCH)"
  echo "       *  scriptdir           - shows ASGS main script directory used by all underlying scripts, (\$SCRIPTDIR)"
  echo "       *  statefile           - shows ASGS state file location, derived from scratchdir; (\$STATEFILE)"
  echo "       *  syslog              - shows ASGS log location, read directly from a valid state file, (\$SYSLOG)"
  echo "       *  workdir             - shows ASGS main script directory used by all underlying scripts, (\$WORK)"
  echo "   list   <param>             - lists different things"
  echo "       *  configs             - lists ASGS configuration files based on year (interactive)"
  echo "       *  profiles            - lists all saved profiles that can be specified by load"
  echo "   set    <param> \"<value>\"   - sets specified profile variables (i.e., variables that do not last after 'exit')"
  echo "       *  config              - sets ASGS configuration file used by 'run', (\$ASGS_CONFIG)"
  echo "       *  editor              - sets default editor, (\$EDITOR)"
  echo "       *  scratchdir          - sets ASGS main script directory used by all underlying scripts, (\$SCRATCH)"
  echo "       *  scriptdir           - sets ASGS main script directory used by all underlying scripts, (\$SCRIPTDIR)"
  echo "       *  workdir             - sets ASGS main script directory used by all underlying scripts, (\$WORK)"
  echo "   delete <name>              - deletes named profile"
  echo "   edit config                - opens up \$ASGS_CONFIG using \$EDITOR (must be set, if not use the 'set editor' command)"
  echo "   goto   <param>             - change current working directory to \$SCRATCH"
  echo "       *  scratchdir          - change current working directory to \$SCRIPTDIR"
  echo "       *  scriptdir           - change current working directory to \$WORK"
  echo "       *  workdir             - change current working directory"
  echo "   load   <profile-name>      - loads a saved profile by name"
  echo "   reload                     - reloads currently loaded profile, re-parses config file (useful for brand new scenarios with no state information)"
  echo "   run                        - runs asgs using config file, \$ASGS_CONFIG must be set (see 'set config'); most handy after 'load'ing a profile"
  echo "   save   [<name>]            - saves an asgs named profile, '<name>' not required if a profile is loaded (in that case, try 'save && reload')"
  echo "   sq                         - shortcut for \"squeue -u \$USER\" (if squeue is available)"
  echo "   verify                     - verfies Perl and Python environments"
  echo "   watchlog                   - executes 'tail -f' on ASGS instance's log"
  echo "   exit                       - exits ASGS shell, returns \$USER to login shell"
}

# xxx DO NOT CUSTOMIZE THIS FILE, IT WILL BE OVERWRITTEN NEXT TIME asgs-brew.pl IS RUN xxx
# xxx THIS FILE IS GENERATED BY asgs-brew.pl                                           xxx
# xxx DO NOT CUSTOMIZE THIS FILE, IT WILL BE OVERWRITTEN NEXT TIME asgs-brew.pl IS RUN xxx

# Function definitions supporting above commands

delete() {
  if [ -z "${1}" ]; then
    echo \'delete\' requires a name parameter, does NOT unload current profile 
    return
  fi
  NAME=${1}
  if [ -e "$HOME/.asgs/$NAME" ]; then
    rm -f "$HOME/.asgs/$NAME"
    echo deleted \'$NAME\'
  else
    echo no saved profile found
  fi
}

edit() {
  case "${1}" in
  config)
    if [ -z "$ASGS_CONFIG" ]; then
      echo "\$ASGS_CONFIG is not set. Use 'set config' to specify a config file."
      return
    fi
    if [ -z "$EDITOR" ]; then
      echo "\$EDITOR is not set. Use 'set editor' to specify a config file."
      return
    fi
    $EDITOR $ASGS_CONFIG
    ;;
  *)
    echo "Only 'edit config' is supported at this time."
    ;;
  esac
}

goto() {
  case "${1}" in
  rundir)
  if [ -e "$RUNDIR" ]; then
    cd $RUNDIR
    pwd
  else
    echo 'rundir not yet defined'
  fi 
  ;;
  scratchdir)
  if [ -e "$SCRATCH" ]; then
    cd $SCRATCH
    pwd
  else
    echo 'scratchdir not yet defined'
  fi 
  ;;
  scriptdir)
  if [ "$SCRIPTDIR" ]; then
    cd $SCRIPTDIR
    pwd
  else
    echo 'scriptdir not yet defined'
  fi 
  ;;
  workdir)
  if [ "$WORK" ]; then
    cd $WORKDIR
    pwd
  else
    echo 'workdir not yet defined'
  fi 
  ;;
  *)
    echo "Only 'rundir', 'scratchdir', 'scriptdir', 'workdir' are supported at this time."
    ;;
  esac
}

list() {
  case "${1}" in
    configs)
      read -p "Show configs for what year? " year
      if [ -d $SCRIPTDIR/config/$year ]; then
        ls $SCRIPTDIR/config/$year/* | less
      else
        echo ASGS configs for $year do not exist 
      fi
      ;;
    profiles)
      if [ ! -d "$HOME/.asgs/" ]; then
        echo no profiles saved
      else
        for profile in $(ls -1 "$HOME/.asgs/" | sort); do
          echo "- $profile"
        done
        return
      fi
      ;;
    *)
     echo "'list configs' and 'list profiles' are supported at this time.'"
     ;;
  esac 
}

reload() {
  if [ -z "$NAME" ]; then
    echo "'reload' requires a profile be loaded first, use 'list-profiles' to list saved profiles."
    return
  fi
  echo "reloading '$NAME' ..."
  load "$NAME"
}

load() {
  if [ -z "${1}" ]; then
    echo \'load\' requires a name parameter, use \'list-profiles\' to list saved profiles
    return
  fi
  NAME=${1}
  if [ -e "$HOME/.asgs/$NAME" ]; then
    . "$HOME/.asgs/$NAME"
    export PS1="asgs ($NAME)> "
    echo loaded \'$NAME\' into current profile;
    if [ -n "$ASGS_CONFIG" ]; then
      # extracts info such as 'instancename' so we can derive the location of the state file, then the log file path and actual run directory
      _parse_config $ASGS_CONFIG
    fi
  else
    echo no saved profile found
  fi
}
load default

_parse_config() {
  if [ ! -e "${1}" ]; then
    echo "warning: config file is set, but the file '${1}' does not exist!"
    return
  fi
  # pull out var info the old fashion way...
  INSTANCENAME=$(grep 'INSTANCENAME=' "${1}" | sed 's/^ *INSTANCENAME=//' | sed 's/ *#.*$//g')
  echo "config file found, instance name is '$INSTANCENAME'"
  STATEFILE="$SCRATCH/${INSTANCENAME}.state"
  echo "loading latest state file information from '${STATEFILE}'."
  _load_state_file $STATEFILE
}

_load_state_file() {
  if [ ! -e "${1}" ]; then
    echo "warning: state file '${1}' does not exist! No indication of first run yet?"
    return
  fi
  . $STATEFILE # we only are about RUNDIR and SYSLOG since they do not change from run to run 
  if [ -z "$RUNDIR" ]; then
    echo "warning: state file does not contain 'RUNDIR' information. Check again later."
    return
  fi
  if [ -z "$SYSLOG" ]; then
    echo "warning: state file does not contain 'SYSLOG' information. Check again later."
    return
  fi
  echo "... found 'RUNDIR' information, set to '$RUNDIR'"
  echo "... found 'SYSLOG' information, set to '$SYSLOG'"
  PROPERTIESFILE="$RUNDIR/run.properties"
  if [ -e "$PROPERTIESFILE" ]; then
    echo "... found 'run.properties' file, at '$PROPERTIESFILE'"
  fi
}

run() {
  if [ -n "${ASGS_CONFIG}" ]; then
    echo "Running ASGS using the config file, '${ASGS_CONFIG}'"
    $SCRIPTDIR/asgs_main.sh -c $ASGS_CONFIG
    # NOTE: asgs_main.sh automatically extracts $SCRIPTDIR based on where it is located;
    # this means that asgs_main.sh will respect $SCRIPTDIR set here by virtue of this capability.
  else
    echo "ASGS_CONFIG must be set before the 'run' command can be used";  
    return;
  fi
}

save() {
  DO_RELOAD=1
  if [ -n "${1}" ]; then 
    NAME=${1}
    DO_RELOAD=0
  elif [ -z "${NAME}" ]; then
    echo "'save' requires a name parameter or pre-loaded profile"
    return
  fi

  if [ ! -d $HOME/.asgs ]; then
    mkdir -p $HOME/.asgs
  fi

  if [ -e "$HOME/.asgs/$NAME" ]; then
    IS_UPDATE=1
  fi

  # be very specific about the "profile variables" saved
  echo "export ASGS_CONFIG=${ASGS_CONFIG}" > "$HOME/.asgs/$NAME"
  echo "export EDITOR=${EDITOR}"    >> "$HOME/.asgs/$NAME"
  echo "export SCRATCH=${SCRATCH}"    >> "$HOME/.asgs/$NAME"
  echo "export SCRIPTDIR=${SCRIPTDIR}"    >> "$HOME/.asgs/$NAME"
  echo "export WORK=${WORK}"    >> "$HOME/.asgs/$NAME"
  
  # update prompt
  export PS1="asgs ($NAME)> "

  if [ -n "$IS_UPDATE" ]; then
    echo profile \'$NAME\' was updated
  else
    echo profile \'$NAME\' was written
  fi

  if [ 1 -eq "$DO_RELOAD" ]; then
    reload
  fi
}

set() {
  if [ -z "${2}" ]; then
    echo "'set' requires 2 arguments - parameter name and value"
    return 
  fi
  case "${1}" in
  config)
    export ASGS_CONFIG=${2}
    echo "ASGS_CONFIG is set to '${ASGS_CONFIG}'"
    ;;
  editor)
    export EDITOR=${2}
    echo "EDITOR is set to '${EDITOR}'"
    ;;
  scriptdir)
    export SCRIPTDIR=${2} 
    echo "SCRIPTDIR is now set to '${SCRIPTDIR}'"
    ;;
  workdir)
    export WORK=${2} 
    echo "WORK is now set to '${WORK}'"
    ;;
  scratchdir)
    export SCRATCH=${2} 
    echo "SCRATCH is now set to '${SCRATCH}'"
    ;;
  *) echo "'set' requires one of the supported parameters: 'config', 'editor', 'scratchdir', 'scriptdir', or 'workdir'"
    ;;
  esac 
}

show() {
  if [ -z "${1}" ]; then
    echo "'set' requires 1 argument - parameter"
    return 
  fi
  case "${1}" in
  config)
    if [ -n "${ASGS_CONFIG}" ]; then
      echo "ASGS_CONFIG is set to '${ASGS_CONFIG}'"
    else
      echo "ASGS_CONFIG is not set to anything. Try, 'set config /path/to/asgs/config.sh' first"
    fi
    ;;
  editor)
    if [ -n "${EDITOR}" ]; then
      echo "EDITOR is set to '${EDITOR}'"
    else
      echo "EDITOR is not set to anything. Try, 'set config vi' first"
    fi
    ;;
  instancename)
    if [ -n "${INSTANCENAME}" ]; then
      echo "INSTANCENAME is set to '${INSTANCENAME}'"
    else
      echo "INSTANCENAME is not set to anything. Have you set the config file yet?"
    fi
    ;;
  rundir)
    if [ -n "${RUNDIR}" ]; then
      echo "RUNDIR is set to '${RUNDIR}'"
    else
      echo "RUNDIR is not set to anything. Does state file exist?" 
    fi
    ;;
  scratchdir)
    if [ -n "${SCRATCH}" ]; then
      echo "SCRATCH is set to '${SCRATCH}'"
    else
      echo "SCRATCH is not set to anything. Try, 'set config /path/to/scratch' first"
    fi
    ;;
  scriptdir)
    if [ -n "${SCRIPTDIR}" ]; then
      echo "SCRIPTDIR is set to '${SCRIPTDIR}'"
    else
      echo "SCRIPTDIR is not set to anything. Try, 'set config /path/to/asgs' first"
    fi
    ;;
  statefile)
    if [ -n "${STATEFILE}" ]; then
      echo "STATEFILE is set to '${STATEFILE}'"
    else
      echo "STATEFILE is not set to anything. Does state file exist?"
    fi
    ;;
  syslog)
    if [ -n "${SYSLOG}" ]; then
      echo "SYSLOG is set to '${SYSLOG}'"
    else
      echo "SYSLOG is not set to anything. Does state file exist?"
    fi
    ;;
  workdir)
    if [ -n "${WORK}" ]; then
      echo "WORK is set to '${WORK}'"
    else
      echo "WORK is not set to anything. Try, 'set config /path/to/work' first"
    fi
    ;;
  *) echo "'show' requires one of the supported parameters: 'config', 'editor', 'rundir', 'scratchdir', 'scriptdir',"
     echo "'statefile', 'syslog', or 'workdir'"
    ;;
  esac 
}

sq() {
  if [ -n $(which squeue) ]; then
    squeue -u $USER  
  else
    echo The `squeue` utility has not been found in your PATH \(slurm is not available\)
  fi
}

watchlog() {
  if [ -z "$SYSLOG" ]; then
    echo "warning: log file "$SYSLOG" does not exist!"
    return
  fi
  echo "type 'ctrl-c' to end"
  echo "tail -f $SYSLOG"
  tail -f $SYSLOG
}

verify() {
  echo verifying Perl Environment:
  which perl
  pushd $SCRIPTDIR > /dev/null 2>&1
  perl $SCRIPTDIR/cloud/general/t/verify-perl-modules.t
  echo verifying Perl scripts can pass compile phase \(perl -c\)
  for file in $(find . -name "*.pl"); do perl -c $file > /dev/null 2>&1 && echo ok     $file || echo not ok $file; done
  which python
  python $SCRIPTDIR/cloud/general/t/verify-python-modules.py && echo Python modules loaded ok
  echo verifying Python scripts can pass compile phase \(python -m py_compile\)
  for file in $(find . -name "*.py"); do
    python -m py_compile $file > /dev/null 2>&1 && echo ok     $file || echo not ok $file;
    # clean up potentially useful *.pyc (compiled python) files
    rm -f ${file}c
  done
  echo benchmarking and verifying netCDF4 module functionality
  pyNETCDFBENCH=$SCRIPTDIR/cloud/general/t/netcdf4-bench.py
  $pyNETCDFBENCH && echo ok $pyNETCDFBENCH works || echo not ok $pyNETCDFBENCH 
  pyNETCDFTUTORIAL=$SCRIPTDIR/cloud/general/t/netcdf4-tutorial.py 
  $pyNETCDFTUTORIAL > /dev/null && echo ok $pyNETCDFTUTORIAL works || echo not ok $pyNETCDFTUTORIAL
  # clean up *.nc from netcdf4-tutorial.py
  rm -f ./*.nc
  popd > /dev/null 2>&1
}

# xxx DO NOT CUSTOMIZE THIS FILE, IT WILL BE OVERWRITTEN NEXT TIME asgs-brew.pl IS RUN xxx
# xxx THIS FILE IS GENERATED BY asgs-brew.pl                                           xxx
# xxx DO NOT CUSTOMIZE THIS FILE, IT WILL BE OVERWRITTEN NEXT TIME asgs-brew.pl IS RUN xxx
