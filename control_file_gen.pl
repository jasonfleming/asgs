#!/usr/bin/env perl
#--------------------------------------------------------------------------
# control_file_gen.pl
#

# This script uses the template fort.15 file and the ATCF formatted fort.22
# file as input and produces a fort.15 file as output. The name of the template
# file and the fort.22 file to be used as input must be specified on the
# command line.
#
# It optionally accepts the csdate (YYYYMMDDHH24), that is, the
# calendar time that corresponds to t=0 in simulation time. If it is
# not provided, the first line in the fort.22 file is used as the cold start
# time, and this time is written to stdout.
#
# It optionally accepts the time in a hotstart file in seconds since cold
# start.
#
# If the time of a hotstart file has been supplied, the fort.15 file
# will be set to hotstart.
#
# It optionally accepts the end time (YYYYMMDDHH24) at which the simulation
# should stop (e.g., if it has gone too far inland to continue to be
# of interest).
#
# If the --name option is set to nowcast, the RNDAY will be calculated such
# that the run will end at the nowcast time.
#
# The --dt option can be used to specify the time step size if it is
# different from the default of 3.0 seconds.
#
# The --bladj option can be used to specify the Boundary Layer Adjustment
# parameter for the Holland model (not used by the asymmetric wind vortex
# model, NWS=9.
#
# The NHSINC will be calculated such that a hotstart file is always generated
# on the last time step of the run.
#
# usage:
#   %perl control_file_gen.pl [--cst csdate] [--hst hstime]
#   [--dt timestep] [--nowcast] [--controltemplate templatefile] < storm1_fort.22
#
#--------------------------------------------------------------------------
# Copyright(C) 2006--2016 Jason Fleming
# Copyright(C) 2006, 2007 Brett Estrade
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
#jgf20120124: standalone usage example for making a fort.15 for the
# ec95d mesh. It was for a tides-only run.
#perl ~/asgs/trunk/control_file_gen.pl --controltemplate ~/asgs/trunk/input/ec_95_fort.15_template --gridname fort.14 --cst 2012010100 --endtime 7 --dt 30.0 --nws 0 --scriptdir ~/asgs/trunk --hsformat binary --stormdir . --name hindcast --fort63freq 3600.0


$^W++;
use strict;
use Getopt::Long;
use Date::Calc;
use Cwd;
#

my $fort61freq=0; # output frequency in SECONDS
my $fort61append; # if defined, output files will be appended across hotstarts
my $fort62freq=0; # output frequency in SECONDS
my $fort62append; # if defined, output files will be appended across hotstarts
my $fort63freq=0; # output frequency in SECONDS
my $fort63append; # if defined, output files will be appended across hotstarts
my $fort64freq=0; # output frequency in SECONDS
my $fort64append; # if defined, output files will be appended across hotstarts
my $fort7172freq=0; # output frequency in SECONDS
my $fort7172append; # if defined, output files will be appended across hotstart
my $fort7374freq=0; # output frequency in SECONDS
my $fort7374append; # if defined, output files will append across hotstarts
my ($fort61, $fort62, $fort63, $fort64, $fort7172, $fort7374);
our $sparseoutput; # if defined, then fort.63 and fort.64 will be sparse ascii
my $hsformat="binary";  # input param for hotstart format: binary or netcdf
my ($fort61netcdf, $fort62netcdf, $fort63netcdf, $fort64netcdf, $fort7172netcdf, $fort7374netcdf); # for netcdf (not ascii) output
my $hotswan = "on"; # "off" if swan has to be cold started (only on first nowcast)
our $netcdf4;  # if defined, then netcdf files should use netcdf4 formatting
#
my @TRACKS = (); # should be few enough to store all in an array for easy access
my $controltemplate;
my $elevstations="null"; # file containing list of adcirc elevation stations
my $velstations="null";  # file with list of adcirc velocity stations
my $metstations="null";  # file with list of adcirc meteorological stations
my $swantemplate;
my $metfile;
my $gridname="nc6b";
our $csdate;
our ($cy, $cm, $cd, $ch, $cmin, $cs); # ADCIRC cold start time
our ($ny, $nm, $nd, $nh, $nmin, $ns); # current ADCIRC time
our ($ey, $em, $ed, $eh, $emin, $es); # ADCIRC end time
our ($oy, $om, $od, $oh, $omin, $os); # OWI start time
my $numelevstations="0"; # number and list of adcirc elevation stations
my $numvelstations="0";  # number and list of adcirc velocity stations
my $nummetstations="0";  # number and list of adcirc meteorological stations
my $startdatetime; # formatted for swan fort.26
my $enddatetime;   # formatted for swan fort.26
my $hstime;      # time, in seconds, of hotstart file (since coldstart)
my $hstime_days; # time, in days, of hotstart file (since coldstart)
our $endtime;    # time at which the run should end (days since coldstart)
our $dt=3.0;      # adcirc time step, in seconds
my $swandt=600.0; # swan time step, in seconds
my $bladj=0.9;
our $enstorm;    # ensemble name of the storm
my $nhcName="STORMNAME"; # storm name given by the nhc
my $tau=0; # forecast period
my $dir=getcwd();
my $nws=0;
my $advisorynum="0";
our $stormDir = "null"; # directory where the fort.15 file will be written
our $advisdir;  # the directory for this run
my $scriptdir = "."; # the directory containing asgs_main.sh
my $particles;  # flag to produce fulldomain current velocity files at an
                # increment of 30 minutes
our $NHSINC;    # time step increment at which to write hot start files
our $NHSTAR;    # writing and format of ADCIRC hotstart output file
our $RNDAY;     # total run length from cold start, in days
my $nffr = -1;  # for flux boundaries; -1: top of fort.20 corresponds to hs
my $ihot;       # whether or not ADCIRC should READ a hotstart file
my $fdcv;       # line that controls full domain current velocity output
our $wtiminc;   # parameters related to met and wave timing
our $rundesc;   # description of run, 1st line in fort.15
our $ensembleid; # run id, 2nd line in fort.15
our $waves = "off"; # set to "on" if adcirc is coupled with swan is being run
our $specifiedRunLength; # time in days for run if there is no externally specified forcing
my $inundationOutput = "off"; # on inundationOutput=.true. in fort.15 template
my ($m2nf, $s2nf, $n2nf, $k2nf, $k1nf, $o1nf, $p1nf, $q1nf); # nodal factors
my ($m2eqarg, $s2eqarg, $n2eqarg, $k2eqarg, $k1eqarg, $o1eqarg, $p1eqarg, $q1eqarg); # equilibrium arguments
my $periodicflux="null";  # the name of a file containing the periodic flux unit discharge data for constant inflow boundaries
my $fluxdata;
my $staticoffset = "null";
my $unitoffsetfile = "null";
GetOptions("controltemplate=s" => \$controltemplate,
           "stormdir=s" => \$stormDir,
           "swantemplate=s" => \$swantemplate,
           "elevstations=s" => \$elevstations,
           "velstations=s" => \$velstations,
           "metstations=s" => \$metstations,
           "metfile=s" => \$metfile,
           "name=s" => \$enstorm,
           "gridname=s" => \$gridname,
           "cst=s" => \$csdate,
           "endtime=s" => \$endtime,
           "dt=s" => \$dt,
           "swandt=s" => \$swandt,
           "bladj=s" => \$bladj,
           "nws=s" => \$nws,
           "advisorynum=s" => \$advisorynum,
           "nhcName=s" => \$nhcName,
           "hstime=s" => \$hstime,
           "advisdir=s" => \$advisdir,
           "scriptdir=s" => \$scriptdir,
           "fort61freq=s" => \$fort61freq,
           "fort62freq=s" => \$fort62freq,
           "fort63freq=s" => \$fort63freq,
           "fort64freq=s" => \$fort64freq,
           "fort7172freq=s" => \$fort7172freq,
           "fort7374freq=s" => \$fort7374freq,
           "fort61append" => \$fort61append,
           "fort62append" => \$fort62append,
           "fort63append" => \$fort63append,
           "fort64append" => \$fort64append,
           "fort7172append" => \$fort7172append,
           "fort7374append" => \$fort7374append,
           "fort61netcdf" => \$fort61netcdf,
           "fort62netcdf" => \$fort62netcdf,
           "fort63netcdf" => \$fort63netcdf,
           "fort64netcdf" => \$fort64netcdf,
           "fort7172netcdf" => \$fort7172netcdf,
           "fort7374netcdf" => \$fort7374netcdf,
           "netcdf4" => \$netcdf4,
           "sparse-output" => \$sparseoutput,
           "hsformat=s" => \$hsformat,
           "hotswan=s" => \$hotswan,
           "periodicflux=s" => \$periodicflux
           );
#
# define stormDir if it is not already
if ( $stormDir eq "null" ) {
   $stormDir = $advisdir."/".$enstorm;
}
#
# create a hash of properties from run.properties
my %runProp;
# open properties file
unless (open(RUNPROP,"<$stormDir/run.properties")) {
   stderrMessage("ERROR","Failed to open $stormDir/run.properties: $!.");
   die;
}
while (<RUNPROP>) {
   my @fields = split ':',$_, 2 ;
   # strip leading and trailing spaces and tabs
   $fields[0] =~ s/^\s|\s+$//g ;
   $fields[1] =~ s/^\s|\s+$//g ;
   $runProp{$fields[0]} = $fields[1];
}
close(RUNPROP);
#
# parse out the pieces of the cold start date
$csdate=~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)/;
$cy = $1;
$cm = $2;
$cd = $3;
$ch = $4;
$cmin = 0.0;
$cs = 0.0;
#
# initialize "now" to a reasonable value
$ny = $1;
$nm = $2;
$nd = $3;
$nh = $4;
$nmin = $cmin;
$ns = $cs;
#
# determine whether SWAN has been turned on
my $waves_digit = int($nws / 100);
if ( abs($waves_digit) == 3 ) {
   $waves = "on";
   stderrMessage("INFO","Wave forcing is active.");
}
stderrMessage("DEBUG","nws is $nws and waves digit is $waves_digit.");
#
#
#----------------------------------------------------
#
#  A D C I R C   C O N T R O L   F I L E
#
# open template file for fort.15
unless (open(TEMPLATE,"<$controltemplate")) {
   stderrMessage("ERROR","Failed to open the fort.15 template file $controltemplate for reading: $!.");
   die;
}
#
# open output control file
unless (open(STORM,">$stormDir/fort.15")) {
   stderrMessage("ERROR","Failed to open the output control file $stormDir/fort.15: $!");
   die;
}
stderrMessage("INFO","The fort.15 file will be written to the directory $stormDir.");
#
# call subroutine that knows how to fill in the fort.15 for each particular
# type of forcing
if ( abs($nws) == 19 || abs($nws) == 319 || abs($nws) == 20 || abs($nws) == 320 || abs($nws) == 8 || abs($nws) == 308 ) {
   stderrMessage("DEBUG","Setting parameters appropriately for vortex model.");
   &vortexModelParameters($nws);
} elsif ( abs($nws) == 12 || abs($nws) == 312 ) {
   &owiParameters();
} elsif ( defined $specifiedRunLength ) {
   stderrMessage("DEBUG","The duration of this $enstorm run is specially defined.");
   &customParameters();
} elsif ( $enstorm eq "hindcast" ) {
   stderrMessage("DEBUG","This is a hindcast.");
   &hindcastParameters();
}
#
# we want a hotstart file if this is a nowcast or hindcast
if ( $enstorm eq "nowcast" || $enstorm eq "hindcast" ) {
   $NHSTAR = 1;
   if ( $hsformat eq "netcdf" ) {
      $NHSTAR = 3;
      if ( defined $netcdf4 ) {
         $NHSTAR = 5;
      }
   }
} else {
   $NHSTAR = 0;
   $NHSINC = 99999;
}
#
# we always look for a fort.68 file, and since we only write one hotstart
# file during the run, we know we will always be left with a fort.67 file.
if ( defined $hstime ) {
   $ihot = 68;
   if ( $hsformat eq "netcdf" ) {
      $ihot = 368;
      if ( defined $netcdf4 ) {
         $ihot = 568;
      }
   }
} else {
   $ihot = 0;
   $nffr = 0;
}
# [de]activate output files with time step increment and with(out) appending.
my $fort61specifier = &getSpecifier($fort61freq,$fort61append,$fort61netcdf);
my $fort62specifier = &getSpecifier($fort62freq,$fort62append,$fort62netcdf);
$fort61 = $fort61specifier . " 0.0 365.0 " . &getIncrement($fort61freq,$dt);
$fort62 = $fort62specifier . " 0.0 365.0 " . &getIncrement($fort62freq,$dt);
#
my $fort63specifier = &getSpecifier($fort63freq,$fort63append,$fort63netcdf);
my $fort64specifier = &getSpecifier($fort64freq,$fort64append,$fort64netcdf);
if ( defined $sparseoutput ) {
   unless ( defined $fort63netcdf ) {
      $fort63specifier *= 4;
   }
   unless ( defined $fort64netcdf ) {
      $fort64specifier *= 4;
   }
}
$fort63 = $fort63specifier . " 0.0 365.0 " . &getIncrement($fort63freq,$dt);
$fort64 = $fort64specifier . " 0.0 365.0 " . &getIncrement($fort64freq,$dt);
my $fort7172specifier = &getSpecifier($fort7172freq,$fort7172append,$fort7172netcdf);
my $fort7374specifier = &getSpecifier($fort7374freq,$fort7374append,$fort7374netcdf);
# Casey 121009: Debug for sparse output.
if ( defined $sparseoutput ) {
   unless ( defined $fort7374netcdf ) {
      $fort7374specifier *= 4;
   }
}
$fort7172 = $fort7172specifier . " 0.0 365.0 " . &getIncrement($fort7172freq,$dt);
$fort7374 = $fort7374specifier . " 0.0 365.0 " . &getIncrement($fort7374freq,$dt);
if ( $nws eq "0" ) {
   $fort7172 = "NO LINE HERE";
   $fort7374 = "NO LINE HERE";
}
# add swan time step to WTIMINC line if waves have been activated
if ( $waves eq "on" ) {
   $wtiminc.=" $swandt"
}
#
# determine if tide_fac.x executable is present, and if so, generate
# nodal factors and equilibrium arguments
my $tides = "off";
if ( -e "$scriptdir/tides/tide_fac.x" && -x "$scriptdir/tides/tide_fac.x" ) {
   my $tide_fac_message = `$scriptdir/tides/tide_fac.x --length $RNDAY --year $cy --month $cm --day $cd --hour $ch -n 8 m2 s2 n2 k1 k2 o1 q1 p1 --outputformat simple --outputdir $stormDir`;
   if ( $tide_fac_message =~ /ERROR|WARNING/ ) {
      stderrMessage("WARNING","There was an issue when running $scriptdir/tides/tide_fac.x: $tide_fac_message.");
   } else {
      stderrMessage("INFO","Nodal factors and equilibrium arguments were written to the file $stormDir/tide_fac.out.");
      # open data file
      unless (open(TIDEFAC,"<$stormDir/tide_fac.out")) {
         stderrMessage("ERROR","Failed to open the file '$advisdir/$enstorm/tide_fac.out' for reading: $!.");
         die;
      }
      # parse out nodal factors and equilibrium arguments from the
      # various constituents
      $tides = "on";
      stderrMessage("INFO","Parsing tidal node factors and equilibrium arguments.");
      while(<TIDEFAC>) {
         my @constituent = split;
         if ( $constituent[0] eq "M2" ) {
            $m2nf = $constituent[1];
            $m2eqarg = $constituent[2];
         } elsif ( $constituent[0] eq "S2" ) {
            $s2nf = $constituent[1];
            $s2eqarg = $constituent[2];
         } elsif  ( $constituent[0] eq "N2" ) {
            $n2nf = $constituent[1];
            $n2eqarg = $constituent[2];
         } elsif ( $constituent[0] eq "K2" ) {
            $k2nf = $constituent[1];
            $k2eqarg = $constituent[2];
         } elsif ( $constituent[0] eq "K1" ) {
            $k1nf = $constituent[1];
            $k1eqarg = $constituent[2];
         } elsif ( $constituent[0] eq "O1" ) {
            $o1nf = $constituent[1];
            $o1eqarg = $constituent[2];
         } elsif ( $constituent[0] eq "P1" ) {
            $p1nf = $constituent[1];
            $p1eqarg = $constituent[2];
         } elsif ( $constituent[0] eq "Q1" ) {
            $q1nf = $constituent[1];
            $q1eqarg = $constituent[2];
         } else {
            stderrMessage("WARNING","Tidal constituent named '$constituent[0]' was unrecognized.");
         }
      }
      close(TIDEFAC);
   }
} else {
   stderrMessage("INFO","The executable that generates the tidal node factors and equilibrium arguments ($scriptdir/tides/tide_fac.x) was not found. Updated nodal factors and equilibrium arguments will not be generated.");
}
#
# load up stations
$numelevstations = &getStations($elevstations,"elevation");
$numvelstations = &getStations($velstations,"velocity");
if ( $nws eq "0" ) {
   stderrMessage("INFO","NWS is zero; meteorological stations will not be written to the fort.15 file.");
   $nummetstations = "NO LINE HERE";
} else {
   $nummetstations = &getStations($metstations,"meteorology");
}
#
# load up the periodicflux data
$fluxdata = &getPeriodicFlux($periodicflux);
#
# apply static offset if specified
my $offsetline = "NO LINE HERE";
$staticoffset = $runProp{'forcing.staticoffset'};
if ( $staticoffset ne "null" && $staticoffset ne "0.0" ) {
   my $unitoffsetfile = $runProp{'adcirc.file.input.unitoffsetfile'};
   my $inputdir = $runProp{'path.inputdir'};
   # open static unit offset file
   unless (open(STATICOFFSET,"<$inputdir/$unitoffsetfile")) {
      stderrMessage("ERROR","Failed to open $inputdir/$unitoffsetfile: $!.");
      die;
   }
   # open static offset file
   unless (open(OFFSET,">$stormDir/offset.dat")) {
      stderrMessage("ERROR","Failed to open $stormDir/offset.dat: $!.");
      die;
   }
   my $offsetcomment = "static offset multiplier is $staticoffset with ramp starting at cold start and reaching full offset at 15.0 days";
   my $offsettimeincrement = "999999.0";
   while(<STATICOFFSET>) {
      s/%comment%/$offsetcomment/;
      s/%timeincrement%/$offsettimeincrement/;
      unless (/NO LINE HERE/) {
         print OFFSET $_;
      }
   }
   close(STATICOFFSET);
   close(OFFSET);
   # FIXME: static offset start and end hardcoded to coldstart and 15.0 days
   $offsetline = "&offsetControl offsetFileName='$stormDir/offset.dat', offsetMultiplier=$staticoffset, offsetRampStart=0.0, offsetRampEnd=1296000.0, offsetRampReferenceTime='coldstart' /";
}
#
#
#
stderrMessage("INFO","Filling in ADCIRC control template (fort.15).");
while(<TEMPLATE>) {
    # if we are looking at the first line, fill in the name of the storm
    # and the advisory number, if available
    s/%StormName%/$rundesc/;
    # if we are looking at the DT line, fill in the time step (seconds)
    s/%DT%/$dt/;
    # if we are looking at the RNDAY line, fill in the total run time (days)
    s/%RNDAY%/$RNDAY/;
    # set whether or not we are going to read a hotstart file
    s/%IHOT%/$ihot/;
    # fill in the parameter that selects which wind model to use
    s/%NWS%/$nws/;
    # fill in the parameter that selects which wind model to use
    s/%NFFR%/$nffr/;
    # fill in nodal factors and equilibrium arguments
    if ( $tides eq "on" ) {
       s/%M2NF%/$m2nf/; s/%M2EQARG%/$m2eqarg/;
       s/%S2NF%/$s2nf/; s/%S2EQARG%/$s2eqarg/;
       s/%N2NF%/$n2nf/; s/%N2EQARG%/$n2eqarg/;
       s/%K2NF%/$k2nf/; s/%K2EQARG%/$k2eqarg/;
       s/%K1NF%/$k1nf/; s/%K1EQARG%/$k1eqarg/;
       s/%O1NF%/$o1nf/; s/%O1EQARG%/$o1eqarg/;
       s/%P1NF%/$p1nf/; s/%P1EQARG%/$p1eqarg/;
       s/%Q1NF%/$q1nf/; s/%Q1EQARG%/$q1eqarg/;
    }
    # fill in the timestep increment that hotstart files will be written at
    s/%NHSINC%/$NHSINC/;
    # fill in whether or not we want a hotstart file out of this
    s/%NHSTAR%/$NHSTAR/;
    # fill in ensemble name -- this is in the comment line
    s/%EnsembleID%/$ensembleid/;
    # may be asymmetric parameters, or wtiminc, rstiminc, etc
    s/%WTIMINC%/$wtiminc/;
    # periodic non-zero inflow
    s/%PERIODICFLUX%/$fluxdata/;
    # elevation stations
    s/%NUMELEVSTATIONS%/$numelevstations/;
    # velocity stations
    s/%NUMVELSTATIONS%/$numvelstations/;
    # meteorological stations
    s/%NUMMETSTATIONS%/$nummetstations/;
    # output options
    s/%FORT61%/$fort61/;
    s/%FORT62%/$fort62/;
    s/%FORT63%/$fort63/;
    s/%FORT64%/$fort64/;
    s/%FORT7172%/$fort7172/;
    s/%FORT7374%/$fort7374/;
    s/%CSYEAR%/$cy/;
    s/%CSMONTH%/$cm/;
    s/%CSDAY%/$cd/;
    s/%CSHOUR%/$ch/;
    s/%CSMIN%/$cmin/;
    s/%CSSEC%/$cs/;
    if (/inundationOutput=.[tT]/) {
       $inundationOutput = "on";
    }
    s/%offsetline%/$offsetline/;
    unless (/NO LINE HERE/) {
       print STORM $_;
    }
}
close(TEMPLATE);
close(STORM);
#
#
#  S W A N   C O N T R O L   F I L E
#
if ( $waves eq "on" ) {
   # open template file for fort.26
   unless (open(TEMPLATE,"<$swantemplate")) {
      stderrMessage("ERROR","Failed to open the swan template file $swantemplate for reading: $!.");
      die;
   }
   #
   # open output fort.26 file
   unless (open(STORM,">$stormDir/fort.26")) {
      stderrMessage("ERROR","Failed to open the output control file $stormDir/fort.26: $!.");
      die;
   }
   stderrMessage("INFO","The fort.26 file will be written to the directory $stormDir.");
   #
   $startdatetime = sprintf("%4d%02d%02d.%02d0000",$ny,$nm,$nd,$nh);
   $enddatetime = sprintf("%4d%02d%02d.%02d0000",$ey,$em,$ed,$eh);
   my $swanhs =  "INIT HOTSTART MULTIPLE 'swan.68'";
   if ( $hotswan eq "off" ) {
      $swanhs = "\$ swan will coldstart";
   }
   #
   stderrMessage("INFO","Filling in swan control template (fort.26).");
   while(<TEMPLATE>) {
       # use the year as the run number
       my $ny72 = substr($ny,0,4);                  # 'nr' in SWAN documentation, max 4 characters
       s/%nr%/$ny72/;
       # if we are looking at the first line, fill in the name of the storm
       # and the advisory number, if available
       my $rundesc72 = substr($rundesc,0,72);       # 'title1' in SWAN documentation, max 72 char
       s/%StormName%/$rundesc72/;
       # if we are looking at the DT line, fill in the time step (seconds)
       s/%swandt%/$swandt/;
       # fill in ensemble name -- this is in the comment line
       my $ensembleid72 = substr($ensembleid,0,72); # 'title2' in SWAN documentation, max 72 char
       s/%EnsembleID%/$ensembleid/;
       # may be asymmetric parameters, or wtiminc, rstiminc, etc
       my $wtiminc72 = substr($wtiminc,0,72);
       s/%WTIMINC%/$wtiminc72/;                     # 'title3' in SWAN documentation, max 72 char
       #
       s/%hotstart%/$swanhs/;
       # swan start time -- corresponds to adcirc hot start time
       s/%startdatetime%/$startdatetime/;
       # swan end time%
       s/%enddatetime%/$enddatetime/;
       print STORM $_;
   }
   close(TEMPLATE);
   close(STORM);
}
#
# append run.properties file
# set components
my $model = "PADCIRC";
my $model_type = "SADC";
my $wind_model = "vortex-nws$nws";
my $run_type = "Forecast";
my $cycle_hour = sprintf("%02d",$nh);
my $currentdate = substr($ny,2,2) . sprintf("%02d%02d",$nm,$nd); # start time
my $date1 = sprintf("%4d%02d%02dT%02d%02d",$ny,$nm,$nd,$nh,$nmin); # start time
my $date2 = sprintf("%4d%02d%02dT%02d%02d",$ny,$nm,$nd,$nh,$nmin); # 1st output
my $date3 = sprintf("%4d%02d%02dT%02d%02d",$ey,$em,$ed,$eh,$emin); # end time
my $runstarttime = sprintf("%4d%02d%02d%02d",$ny,$nm,$nd,$nh); # start time
my $runendtime = sprintf("%4d%02d%02d%02d",$ey,$em,$ed,$eh); # end time
if ( $waves eq "on" ) {
   $model_type = "SPDS";
   $model = "PADCSWAN";
}
if ( $nws == 0 ) {
   $wind_model = "none";
}
if ( abs($nws) == 12 || abs($nws) == 312 ) {
   $wind_model = "WNAMAW12-NCP";
   $cycle_hour = sprintf("%02d",$oh);
   $currentdate = substr($oy,2,2) . sprintf("%02d%02d",$om,$od); # start time
   $date1 = sprintf("%4d%02d%02dT%02d%02d",$oy,$om,$od,$oh,$omin);
}
if ( $enstorm eq "nowcast" ) {
   $run_type = "Nowcast";
} elsif ( $enstorm eq "hindcast" ) {
   $run_type = "Hindcast";
}
# last time step of model output contained in the file
my $rp_fname = $model_type . $gridname . "-UNC_" . $wind_model . "_" . $date1 . "_" . $date2 . "_" . $date3 . "_" . $cycle_hour . "_run.properties";
my $prodid = $model_type . $gridname . "-UNC_" . $wind_model . "_" . $date1 . "_" . $date2 . "_" . $date3 . "_" . $cycle_hour . "<field>_Z.nc.gz";
stderrMessage("INFO","Opening run.properties file for writing.");
unless (open(RUNPROPS,">>$stormDir/run.properties")) {
   stderrMessage("ERROR","Failed to open the $stormDir/run.properties file for appending: $!.");
   die;
}
# If we aren't using a vortex met model, we don't have a track
# file, but the CERA web app still needs to have values for these
# properties. In the case of a vortex met model, these values are
# filled in by the storm_track_gen.pl script.
if ( abs($nws) != 19 && abs($nws) != 319 && abs($nws) != 20 && abs($nws) != 320 ) {
   printf RUNPROPS "track_raw_dat : notrack\n";
   printf RUNPROPS "track_raw_fst : notrack\n";
   printf RUNPROPS "track_modified : notrack\n";
}
printf RUNPROPS "year : $ny\n";
printf RUNPROPS "directory storm : $stormDir\n";
printf RUNPROPS "mesh : $gridname\n";
printf RUNPROPS "RunType : $run_type\n";
printf RUNPROPS "ADCIRCgrid : $gridname\n";
# only write the stornmame if there is vortex forcing and it is not
# already in the properties file
# FIXME: if the stormname property exists but is null or empty, it should be
# removed from the run.properties file
if ( abs($nws) == 19 || abs($nws) == 319 || abs($nws) == 20 || abs($nws) == 320 || abs($nws) == 8 || abs($nws) == 309 ) {
   if ( ! exists $runProp{'stormname'} || $runProp{'stormname'} eq "" || $runProp{'stormname'} eq "null" ) {
      printf RUNPROPS "stormname : $nhcName\n";
   }
}
if ( abs($nws) == 19 || abs($nws) == 319 || abs($nws) == 20 || abs($nws) == 320 || abs($nws) == 8 || abs($nws) == 309 ) {
   if ( ! exists $runProp{'forcing.tropicalcyclone.stormname'} || $runProp{'forcing.tropicalcyclone.stormname'} eq "" || $runProp{'forcing.tropicalcyclone.stormname'} eq "null" ) {
      printf RUNPROPS "forcing.tropicalcyclone.stormname : $nhcName\n";
   }
}
printf RUNPROPS "currentcycle : $cycle_hour\n";
printf RUNPROPS "currentdate : $currentdate\n";
printf RUNPROPS "advisory : $advisorynum\n";
printf RUNPROPS "prodID : $prodid\n";
if (defined $hstime) {
   printf RUNPROPS "InitialHotStartTime : $hstime\n";
}
printf RUNPROPS "RunStartTime : $runstarttime\n";
printf RUNPROPS "RunEndTime : $runendtime\n";
printf RUNPROPS "ColdStartTime : $csdate\n";
printf RUNPROPS "WindModel : $wind_model\n";
printf RUNPROPS "Model : $model\n";
# write the names of the output files to the run.properties file
stderrMessage("INFO","Writing file names and formats to run.properties file.");
&writeFileName("fort.61",$fort61specifier);
&writeFileName("fort.62",$fort62specifier);
&writeFileName("fort.63",$fort63specifier);
&writeFileName("fort.64",$fort64specifier);
&writeFileName("fort.71",$fort7172specifier);
&writeFileName("fort.72",$fort7172specifier);
&writeFileName("fort.73",$fort7374specifier);
&writeFileName("fort.74",$fort7374specifier);
&writeFileName("maxele.63",$fort63specifier);
&writeFileName("maxvel.63",$fort64specifier);
&writeFileName("maxwvel.63",$fort7374specifier);
&writeFileName("minpr.63",$fort7374specifier);
if ( $waves eq "on" ) {
   &writeFileName("maxrs.63",$fort7374specifier);
   &writeFileName("swan_DIR.63",$fort7374specifier);
   &writeFileName("swan_DIR_max.63",$fort7374specifier);
   &writeFileName("swan_HS.63",$fort7374specifier);
   &writeFileName("swan_HS_max.63",$fort7374specifier);
   &writeFileName("swan_TMM10.63",$fort7374specifier);
   &writeFileName("swan_TMM10_max.63",$fort7374specifier);
   &writeFileName("swan_TPS.63",$fort7374specifier);
   &writeFileName("swan_TPS_max.63",$fort7374specifier);
}
if ($inundationOutput eq "on") {
   &writeFileName("initiallydry.63",$fort63specifier);
   &writeFileName("inundationtime.63",$fort63specifier);
   &writeFileName("maxinundepth.63",$fort63specifier);
   &writeFileName("everdried.63",$fort63specifier);
   &writeFileName("endrisinginun.63",$fort63specifier);
}
close(RUNPROPS);
stderrMessage("INFO","Wrote run.properties file $stormDir/run.properties.");
exit;
#
#
#--------------------------------------------------------------------------
#   S U B   W R I T E   F I L E   N A M E
#
# If an output file will be available, its name and type is written
# to the run.properties file.
#--------------------------------------------------------------------------
sub writeFileName () {
   my $identifier = shift;
   my $specifier = shift;
   #
   my $format = "ascii"; # default output file format
   my $filename = $identifier; # default (ascii) name of output file
   #
   # if there won't be any output of this type, just return without
   # writing anything to the run.properties file
   if ( $specifier == 0 ) {
      return;
   }
   # create the hash for relating the basic file identifier with the
   # long winded file type description
   my %ids_descs;
   $ids_descs{"fort.61"} = "Water Surface Elevation Stations";
   $ids_descs{"fort.62"} = "Water Current Velocity Stations";
   $ids_descs{"fort.63"} = "Water Surface Elevation";
   $ids_descs{"fort.64"} = "Water Current Velocity";
   $ids_descs{"fort.71"} = "Barometric Pressure Stations";
   $ids_descs{"fort.72"} = "Wind Velocity Stations";
   $ids_descs{"fort.73"} = "Barometric Pressure";
   $ids_descs{"fort.74"} = "Wind Velocity";
   $ids_descs{"maxele.63"} = "Maximum Water Surface Elevation";
   $ids_descs{"maxvel.63"} = "Maximum Current Speed";
   $ids_descs{"maxwvel.63"} = "Maximum Wind Speed";
   $ids_descs{"minpr.63"} = "Minimum Barometric Pressure";
   $ids_descs{"maxrs.63"} = "Maximum Wave Radiation Stress";
   $ids_descs{"swan_DIR.63"} = "Mean Wave Direction";
   $ids_descs{"swan_DIR_max.63"} = "Maximum Mean Wave Direction";
   $ids_descs{"swan_HS.63"} = "Significant Wave Height";
   $ids_descs{"swan_HS_max.63"} = "Maximum Significant Wave Height";
   $ids_descs{"swan_TMM10.63"} = "Mean Wave Period";
   $ids_descs{"swan_TMM10_max.63"} = "Maximum Mean Wave Period";
   $ids_descs{"swan_TPS.63"} = "Peak Wave Period";
   $ids_descs{"swan_TPS_max.63"} = "Maximum Peak Wave Period";
   $ids_descs{"initiallydry.63"} = "Initially Dry";
   $ids_descs{"inundationtime.63"} = "Inundation Time";
   $ids_descs{"maxinundepth.63"} = "Maximum Inundation Depth";
   $ids_descs{"everdried.63"} = "Ever Dried";
   $ids_descs{"endrisinginun.63"} = "End Rising Inundation";
   #
   if ( abs($specifier) == 3 || abs($specifier) == 5 ) {
      $filename = $filename . ".nc";
      $format = "netcdf";
   }
   if ( abs($specifier) == 4 ) {
      $format = "sparse-ascii";
   }
   printf RUNPROPS "$ids_descs{$identifier} File Name : $filename\n";
   printf RUNPROPS "$ids_descs{$identifier} Format : $format\n";
}
#
#
#--------------------------------------------------------------------------
#   S U B   G E T   S P E C I F I E R
#
# Determines the correct output specifier for output files based on
# the output frequency, whether or not the files should be appended,
# and whether or not the netcdf format is used (ascii is the default).
#--------------------------------------------------------------------------
sub getSpecifier () {
   my $freq = shift;
   my $append = shift;
   my $netcdf = shift;
   my $specifier;

   if ( $freq == 0 ) {
      $specifier = "0";
   } else {
      if ( defined $append ) {
         $specifier = "1";
      } else {
         $specifier = "-1";
      }
      if ( defined $netcdf ) {
         if ( defined $netcdf4 ) {
            $specifier *= 5;
         } else {
            $specifier *= 3;
         }
      }
   }
   return $specifier;
}
#
#--------------------------------------------------------------------------
#   S U B   G E T   I N C R E M E N T
#
# Determines the correct time step increment based on the output frequency
# and time step size.
#--------------------------------------------------------------------------
sub getIncrement () {
   my $freq = shift;
   my $timestepsize = shift;
   my $increment;
   if ( $freq == 0 ) {
      $increment = "99999";
   } else {
      $increment = int($freq/$timestepsize);
   }
   return $increment;
}
#
#--------------------------------------------------------------------------
#   S U B   G E T   S T A T I O N S
#
# Pulls in the stations from an external file.
#--------------------------------------------------------------------------
sub getStations () {
   my $station_file = shift;
   my $station_type = shift;
#
   my $numstations = "";
   my $station_var = "NSTAE";
   if ( $station_type eq "velocity" ) {
      $station_var = "NSTAV";
   }
   if ( $station_type eq "meteorology" ) {
      $station_var = "NSTAM";
   }
   if ( $station_file =~ /null/) {
      $numstations = "0   ! $station_var" ;
      stderrMessage("INFO","There are no $station_type stations.");
      return $numstations; # early return
   }
   unless (open(STATIONS,"<$station_file")) {
      stderrMessage("ERROR","Failed to open the $station_type stations file $station_file for reading: $!.");
      die;
   }
   my $number=0;
   while (<STATIONS>) {
      $_ =~ s/^\s+//;
      next if (substr($_,0,1) eq '#');  # skip comment lines in the stations file
      $numstations.=$_;
      $number++;
   }
   close(STATIONS);
   stderrMessage("INFO","There are $number $station_type stations in the file '$station_file'.");
   chomp($numstations);
   # need to add this as a sort of comment in the fort.15 for the post
   # processing script station_transpose.pl to find
   $numstations = $number . " " . $station_file . " " . $station_var . "\n" . $numstations;
   return $numstations;
}
#
#-------------------------------------------------------------------------
#   S U B    G E T  P E R I O D I C  F L U X
#
#  gets data for periodic non-zero inflow boundaries from a separate file
#  for example, a file generated by the riverFlow.pl script during
#  model configuration.
#-------------------------------------------------------------------------
sub getPeriodicFlux {
   my $flux_file=shift;
   if ($flux_file =~ /null/){
      stderrMessage("INFO","No periodic inflow boundary data file was specified/");
      return
   }
   unless (open(FLUXFILE,"<$flux_file")) {
      stderrMessage("ERROR","Failed to open $flux_file for reading: $!.");
      die;
   }
   my $fluxdata='';
   while (<FLUXFILE>){
       $fluxdata.=$_;
   }
   close(FLUXFILE);
   stderrMessage("INFO","Inserting periodic inflow boundary data from $flux_file.");
   chomp $fluxdata;
   return $fluxdata;
}
#
#
#--------------------------------------------------------------------------
#   S U B    H I N D C A S T  P A R A M E T E R S
#
# Determines parameter values for the control file when running
# ADCIRC during a hindcast with no met forcing.
#--------------------------------------------------------------------------
sub hindcastParameters () {
    $rundesc = "cs:$csdate"."0000 cy: ASGS hindcast";
    $RNDAY = $endtime; #FIX: this should be a date, not days
    $NHSINC = int(($RNDAY*86400.0)/$dt);
    ($ey,$em,$ed,$eh,$emin,$es) =
       Date::Calc::Add_Delta_DHMS($cy,$cm,$cd,$ch,$cmin,$cs,$endtime,0,0,0);
    $nws = 0;
    $ensembleid = "$endtime day hindcast run";
    $wtiminc = "NO LINE HERE";
    stderrMessage("DEBUG","Finished setting hindcast parameters.");
}
#
#--------------------------------------------------------------------------
#   S U B    C U S T O M   P A R A M E T E R S
#
# Determines parameter values for the control file when running
# ADCIRC without external forcing (e.g., for running ADCIRC tests).
#--------------------------------------------------------------------------
sub customParameters () {
    $rundesc = "cs:$csdate"."0000 cy: ASGS";
    my $alreadyElapsedDays = 0.0;
    if ( defined $hstime && $hstime != 0 ) {
       $alreadyElapsedDays = $hstime / 86400.0;
    }
    $RNDAY = $specifiedRunLength + $alreadyElapsedDays;
    $NHSINC = int(($RNDAY*86400.0)/$dt);
    $nws = 0;
    $ensembleid = "$enstorm $specifiedRunLength day run";
       #
   # determine the relationship between the start of the NAM data and the
   # current time in the ADCIRC run
   if ( defined $hstime && $hstime != 0 ) {
      # now add the hotstart seconds
      ($ny,$nm,$nd,$nh,$nmin,$ns) =
         Date::Calc::Add_Delta_DHMS($cy,$cm,$cd,$ch,0,0,0,0,0,$hstime);
   } else {
      # the hotstart time was not provided, or it was provided and is equal to 0
      # therefore the current ADCIRC time is the cold start time, t=0
      $ny = $cy;
      $nm = $cm;
      $nd = $cd;
      $nh = $ch;
      $nmin = 0;
      $ns = 0;
   }
   ($ey,$em,$ed,$eh,$emin,$es) =
      Date::Calc::Add_Delta_DHMS($ny,$nm,$nd,$nh,0,0,$specifiedRunLength,0,0,0);
    $wtiminc = "NO LINE HERE";
   # create the runme file, if this is a nowcast that has an ending time
   # that is later than the previous hotstart
   if ( $enstorm eq "nowcast" && $specifiedRunLength != 0 ) {
      open(RUNME,">$stormDir/runme") || die "ERROR: control_file_gen.pl: Failed to open runme file for writing in the directory $stormDir: $!.";
      printf RUNME "$specifiedRunLength day nowcast\n";
      close(RUNME);
   }
   stderrMessage("DEBUG","Finished setting specified run length.");
}

#
#--------------------------------------------------------------------------
#   S U B   O W I  P A R A M E T E R S
#
# Determines parameter values for the control file when running
# ADCIRC with OWI formatted meteorological data (NWS12).
#--------------------------------------------------------------------------
sub owiParameters () {
   #
   # open met file
   open(METFILE,"<$stormDir/fort.22") || die "ERROR: control_file_gen.pl: Failed to open OWI (NWS12) file $stormDir/fort.22 for reading: $!.";
   my $line = <METFILE>;
   close(METFILE);
   $line =~ /^# (\d+)/;
   $wtiminc = $1;
   #
   # determine the relationship between the start of the NAM data and the
   # current time in the ADCIRC run
   if ( defined $hstime && $hstime != 0 ) {
      # now add the hotstart seconds
      ($ny,$nm,$nd,$nh,$nmin,$ns) =
         Date::Calc::Add_Delta_DHMS($cy,$cm,$cd,$ch,0,0,0,0,0,$hstime);
   } else {
      # the hotstart time was not provided, or it was provided and is equal to 0
      # therefore the current ADCIRC time is the cold start time, t=0
      $ny = $cy;
      $nm = $cm;
      $nd = $cd;
      $nh = $ch;
      $nmin = 0;
      $ns = 0;
   }
   #
   # open file that will contain the hotstartdate
   open(HSD,">$stormDir/hotstartdate") || die "ERROR: control_file_gen.pl: Failed to open the HOTSTARTDATE file $stormDir/hotstartdate: $!.";
   my $hotstartdate = sprintf("%4d%02d%02d%02d",$ny,$nm,$nd,$nh);
   stderrMessage("INFO","The file containing the hotstartdate '$hotstartdate' will be written to the directory $stormDir.");
   printf HSD $hotstartdate;
   close(HSD);
   # determine the date time of the start and end of the OWI files
   my $owistart = $hotstartdate; # reasonable default
   my $owiend = "nullend";
   # if converted from NAM output
   my @fort221 = glob($stormDir."/NAM*.221");
   if (@fort221) {
      $fort221[0] =~ /NAM_(\d+)/;
      $owistart = $1;
      $fort221[0] =~ /(\d+).221$/;
      $owiend = $1;
   } else {
      # owi files supplied as-is
      my @fort221 = glob($stormDir."/*.221");
      if (@fort221) {
         open(FORT221,"<$fort221[0]") || die "ERROR: control_file_gen.pl: Failed to open the fort.221 file $stormDir/$fort221[0]: $!.";
         my $header221 = <FORT221>;
         close(FORT221);
         my @fields221 = split(" ",$header221);
         $owistart = $fields221[-2];
         $owiend = $fields221[-1];
      }
   }
   # create run description
   $rundesc = "cs:$csdate"."0000 cy:$owistart ASGS NAM";
   $owistart =~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)/;
   $oy = $1;
   $om = $2;
   $od = $3;
   $oh = $4;
   $omin = 0;
   $os = 0;
   #
   # get difference
   (my $ddays, my $dhrs, my $dmin, my $dsec)
           = Date::Calc::Delta_DHMS(
                $ny,$nm,$nd,$nh,0,0,
                $oy,$om,$od,$oh,0,0);
   # find the difference in seconds
   my $blank_time = $ddays*86400.0 + $dhrs*3600.0 + $dmin*60.0 + $dsec;
   stderrMessage("INFO","Blank time is '$blank_time'.");
   # calculate the number of blank snaps (or the number of
   # snaps to be skipped in the OWI file if it starts before the
   # current time in the ADCIRC run)
   my $nwbs = int($blank_time/$wtiminc);
   stderrMessage("INFO","nwbs is '$nwbs'");
   my $nwset = 1;
   # hack to see if there is an additional, optional region scale set of
   # win/pre files
   my @fort223 = glob($stormDir."/*.223");
   if (@fort223) {
      $nwset = 2;
   }
   stderrMessage("INFO","nwset is '$nwset'");
   #
   # create the fort.22 output file, which is the wind input file for ADCIRC
   open(MEMBER,">$stormDir/fort.22") || die "ERROR: control_file_gen.pl: Failed to open file for ensemble member '$enstorm' to write $stormDir/fort.22 file: $!.";
   printf MEMBER "$nwset\n"; # nwset
   printf MEMBER "$nwbs\n"; # nwbs
   printf MEMBER "1.0\n";   # dwm
   close(MEMBER);
   stderrMessage("INFO","The OWI file ends at '$owiend'.");
   $owiend =~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)/;
   $ey = $1;
   $em = $2;
   $ed = $3;
   $eh = $4;
   $emin = 0;
   $es = 0;
   #
   # get difference
   (my $ddays, my $dhrs, my $dmin, my $dsec)
           = Date::Calc::Delta_DHMS(
                $cy,$cm,$cd,$ch,0,0,
                $ey,$em,$ed,$eh,0,0);
   # find the new total run length in days
   $RNDAY = $ddays + $dhrs/24.0 + $dmin/1440.0 + $dsec/86400.0;
   # determine the number of hours of this run, from hotstart to end
   (my $ddays, my $dhrs, my $dmin, my $dsec)
           = Date::Calc::Delta_DHMS(
                $ny,$nm,$nd,$nh,0,0,
                $ey,$em,$ed,$eh,0,0);
   my $addHours = $ddays*24.0 + $dhrs + $dmin/60.0 + $dsec/3600.0;
   $ensembleid = $addHours . " hour " . $enstorm . " run";
   $NHSINC = int(($RNDAY*86400.0)/$dt);
   #
   # create the runme file, if this is a nowcast
   if ( $enstorm eq "nowcast" ) {
      open(RUNME,">$stormDir/runme") || die "ERROR: control_file_gen.pl: Failed to open runme file for writing in the directory $stormDir: $!.";
      printf RUNME "$ensembleid\n";
   }
   close(RUNME);
}
#
#--------------------------------------------------------------------------
#   S U B   V O R T E X   M O D E L   P A R A M E T E R S
#
# Determines parameter values for the control file when running
# the with tropical cyclone vortex models (asymmetric, nws=19; or
# generalized asymmetric holland model, nws=20).
#--------------------------------------------------------------------------
sub vortexModelParameters () {
   my $nws = shift;
   my $geofactor = 1; # turns on Coriolis for GAHM; this is the default
   $ensembleid = $enstorm;
   my $geofactor = 1; # turns on Coriolis for GAHM; this is the default
   #
   # open met file containing datetime data
   unless (open(METFILE,"<$metfile")) {
      stderrMessage("ERROR","Failed to open meteorological (ATCF-formatted) fort.22 file '$metfile' for reading: $!.");
      die;
   }
   stderrMessage("DEBUG","Successfully opened meteorological (ATCF-formatted) fort.22 file '$metfile' for reading.");
   #
   # determine date time at end of hindcast
   #
   # Build track list
   while (<METFILE>) {
      chomp($_);
      my @tmp = ();
      # split and remove any spaces
      foreach my $item (split(',',$_)) {
         $item =~ s/\s*//g;
         push(@tmp,$item);
      }
      # 2d array of arrays; [@tmp] creates an anon array in each
      # element of @TRACK
      push(@TRACKS,[@tmp]);
   }
   #
   # find last hindcast line
   my $track;
   my $nowcast;
   foreach $track (reverse(@TRACKS)) {
      if (@{$track}[4] =~ m/BEST/) {
         if ( $nhcName eq "STORMNAME" ) {
            # We need to get the storm name from the last hindcast line
            if ( defined $track->[27] ) {
               $nhcName = $track->[27];
            } else {
               stderrMessage("WARNING","The name of the storm does not appear in the hindcast.");
            }
         }
         # also grab the last hindcast time; this will be the nowcast time
         $nowcast = $track->[2]; # yyyymmddhh
         last;
      }
   }
   #
   # convert hotstart time (in days since coldstart) if necessary
   if ( $hstime ) {
      $hstime_days = $hstime/86400.0;
   }
   # get end time
   my $end; # yyyymmddhh
   # for a nowcast, end the run at the end of the hindcast
   if ( $enstorm eq "nowcast" ) {
      $end = $nowcast;
      stderrMessage("INFO","New $enstorm time is $end.");
   } elsif ( $endtime ) {
      # if this is not a nowcast, and the end time has been specified, end then
      $end = $endtime
   } else {
      # this is not a nowcast; end time was not explicitly specified,
      # get end time based on either
      # 1. running out of fort.22 file or
      # 2. two or more days inland
      my $ty;  # level of tropical cyclone development
      my $now_inland; # boolean, 1 if TY is "IN"
      my $tin; # time since the first occurrence of TY as "IN"
      my $tin_year;
      my $tin_mon;
      my $tin_day;
      my $tin_hour;
      my $tin_min;
      my $tin_sec;
      my $tin_tau; # forecast period at first occurrence of TY as "IN"
      my $c_year;  # time of line currently being processed
      my $c_mon;
      my $c_day;
      my $c_hour;
      my $c_min;
      my $c_sec;
      my $ddays;
      my $dhrs;
      my $dmin;
      my $dsec; # difference btw time inland and time on current line
      foreach $track (@TRACKS) {
#        my $lat = substr(@{$track}[6],0,3); # doesn't work if only 2 digits
        #@{$track}[6] =~ /[0-9]*/;
        $_ = @{$track}[6];
        /([0-9]*)/;
        $end = $track->[2];
        $tau = $track->[5];
        $ty = @{$track}[10];
        if ( $ty eq "IN" and (not $now_inland) ) {
           $now_inland = 1;
           $tin = @{$track}[2]; # time at first occurrence of "IN" (inland)
           $tin =~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)/;
           $tin_year = $1;
           $tin_mon = $2;
           $tin_day = $3;
           $tin_hour = $4;
           $tin_min = 0;
           $tin_sec = 0;
           $tin_tau = @{$track}[5]
        }
        if ( $now_inland ) {
           $end =~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)/;
           $c_year = $1;
           $c_mon = $2;
           $c_day = $3;
           $c_hour = $4;
           $c_min = 0;
           $c_sec = 0;
           #
           # get difference between first occurrence of IN (inland)
           # and the time on the current track line
           ($ddays,$dhrs,$dmin,$dsec)
              = Date::Calc::Delta_DHMS(
                $tin_year,$tin_mon,$tin_day,$tin_hour,$tin_min,$tin_sec,
                $c_year,$c_mon,$c_day,$c_hour,$c_min,$c_sec);
           my $time_inland = $ddays + $dhrs/24 + $dmin/1440 + $dsec/86400 + ($tau-$tin_tau)/24;
           if ( $time_inland >= 2.0 ) {
              last; # jump out of loop with current track as last track
           }
        }
        # compute the end date and time using the yyyymmdd date and the
        # tau from the track file when using the symmetric vortex model
        if ( $nws == 8 || $nws == 308 ) {
           $end =~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)/;
           $ey = $1;
           $em = $2;
           $ed = $3;
           $eh = $4;
           $emin = 0.0;
           $es = 0.0;
           ($ey,$em,$ed,$eh,$emin,$es) =
              Date::Calc::Add_Delta_DHMS($ey,$em,$ed,$eh,$emin,$es,0,$tau,0,0);
           $end = sprintf("%4d%02d%02d%02d",$ey,$em,$ed,$eh);
        }
      }
   }
   stderrMessage("INFO","The fort.15 file will be configured to end on $end.");
   if ( defined $hstime && $hstime != 0 ) {
      # now add the hotstart seconds
      ($ny,$nm,$nd,$nh,$nmin,$ns) =
         Date::Calc::Add_Delta_DHMS($cy,$cm,$cd,$ch,$cmin,$cs,0,0,0,$hstime);
   } else {
      # the hotstart time was not provided, or it was provided and is equal to 0
      # therefore the current ADCIRC time is the cold start time, t=0
      $ny = $cy;
      $nm = $cm;
      $nd = $cd;
      $nh = $ch;
      $nmin = 0;
      $ns = 0;
   }
   #
   $end =~ m/(\d\d\d\d)(\d\d)(\d\d)(\d\d)/;
   $ey = $1;
   $em = $2;
   $ed = $3;
   $eh = $4;
   $emin = 0.0;
   $es = 0.0;
   #
   # get total difference btw cold start time and end time ... this is RNDAY
   my ($days,$hours,$minutes,$seconds)
      = Date::Calc::Delta_DHMS(
         $cy,$cm,$cd,$ch,$cmin,$cs,
         $ey,$em,$ed,$eh,$emin,$es);
   # RNDAY is diff btw cold start time and end time
   # For a forecast, RNDAY is one time step short of the total time to ensure
   # that we won't run out of storm data at the end of the fort.22
   # For a nowcast, RNDAY will be one time step long, so that we end at
   # the nowcast time, even if ADCIRC rounds down the number of timesteps
   # jgf20110629: Lets see if we can get the nowcast to stop at the exact time
   # that we want
   $RNDAY = $days + $hours/24.0 + $minutes/1440.0 + $seconds/86400.0;
   my $RNDAY_orig = $RNDAY;

   # If RNDAY is less than two timesteps, make sure it is at least
   #  two timesteps.
   # This can happen if we start up from a fort.22 that has only one BEST line,
   # i.e., it starts at the nowcast. RNDAY would be zero in this case, except
   # our algorithm actually stops one ts short of the full time, so RNDAY is
   # actually negative in this case. ADCIRC needs at least two timesteps from
   # coldstart to create a valid hotstart file.
   my $runlength_seconds = $RNDAY*86400.0;
   if ( $hstime ) {
      $runlength_seconds-=$hstime;
   }
   my $min_runlength = 2*$dt;
   # if we coldstart at the nowcast, we may not have calculated a runlength
   # longer than the minimum
   my $goodRunlength = 1;
   if ( $runlength_seconds < $min_runlength ) {
      if ( $enstorm eq "nowcast" ) {
         $goodRunlength = 0;
      }
      stderrMessage("INFO","Runlength was calculated as $runlength_seconds seconds, which is less than the minimum runlength of $min_runlength seconds. The RNDAY will be adjusted so that it ADCIRC runs for the minimum length of simulation time.");
      # recalculate the RNDAY as the hotstart time plus the minimal runlength
      if ( $hstime ) {
         $RNDAY=$hstime_days + ($min_runlength/86400.0);
      } else {
         $RNDAY=$min_runlength/86400.0;
      }
      $runlength_seconds = $min_runlength;
   }
   #
   # if this is an update from hindcast to nowcast, calculate the hotstart
   # increment so that we only write a single hotstart file at the end of
   # the run. If this is a forecast, don't write a hotstart file at all.
   $NHSINC = int(($RNDAY*86400.0)/$dt);
   #
   # If we have swan coupling, we may need to add some run time, after
   # the adcirc hotstart file was written, to give swan a chance to write
   # its hotstart file. After adcirc has written its hotstart file,
   # swan has to run its time own time step, and then write
   # the swan hotstart file.
   if ( $waves eq "on" ) {
      my $total_time = $RNDAY*86400.0; # in seconds
      # unusual but possible for the total run time to be less than the swan
      # time step
      if ( $total_time < $swandt ) {
         $total_time = $swandt; # run for at least one swan time step
         $RNDAY = $total_time / 86400.0; # convert to days
         $NHSINC = int(($RNDAY*86400.0)/$dt);
      }
   }
   # check to see if the RNDAY had to be modified from the value calculated
   # purely from the met file ... if so, modify the ending time accordingly
   if ( $RNDAY != $RNDAY_orig ) {
      ($ey,$em,$ed,$eh,$emin,$es) =
       Date::Calc::Add_Delta_DHMS($cy,$cm,$cd,$ch,$cmin,$cs,$RNDAY,0,0,0);
   }
   # create the runme file, if this is a nowcast that has an ending time
   # that is later than the previous hotstart
   if ( $enstorm eq "nowcast" && $goodRunlength == 1 ) {
      my $runlengthHours = ( $RNDAY*86400.0 - $hstime ) / 3600.0;
      open(RUNME,">$stormDir/runme") || die "ERROR: control_file_gen.pl: Failed to open runme file for writing in the directory $stormDir: $!.";
      printf RUNME "$runlengthHours hour nowcast\n";
      close(RUNME);
   }
   #
   # create run description
   $rundesc = "cs:$csdate"."0000 cy:$nhcName$advisorynum ASGS";
   # create the WTIMINC line
   $wtiminc = $cy." ".$cm." ".$cd." ".$ch." 1 ".$bladj;
   if ( abs($nws) == 20 || abs($nws) == 320 ) {
      $wtiminc .= " $geofactor";
   }
}
#
#--------------------------------------------------------------------------
#   S U B   S T D E R R  M E S S A G E
#
# Writes a log message to standard error.
#--------------------------------------------------------------------------
sub stderrMessage () {
   my $level = shift;
   my $message = shift;
   my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
   (my $second, my $minute, my $hour, my $dayOfMonth, my $month, my $yearOffset, my $dayOfWeek, my $dayOfYear, my $daylightSavings) = localtime();
   my $year = 1900 + $yearOffset;
   my $hms = sprintf("%02d:%02d:%02d",$hour, $minute, $second);
   my $theTime = "[$year-$months[$month]-$dayOfMonth-T$hms]";
   printf STDERR "$theTime $level: $enstorm: control_file_gen.pl: $message\n";
   if ($level eq "ERROR") {
      sleep 60
   }
}


