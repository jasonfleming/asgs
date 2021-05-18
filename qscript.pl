#!/usr/bin/env perl
#--------------------------------------------------------------------------
# qscript.pl : use run.properties to fill in qscript.template
#--------------------------------------------------------------------------
# Copyright(C) 2006--2019 Jason Fleming
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
#
#--------------------------------------------------------------------------
$^W++;
use strict;
use integer;
use Getopt::Long;
use Date::Calc;
use Date::Handler;
#
my $ncpu = "null";      # number of CPUs the job should run on
my $totalcpu = "null";  # ncpu + numwriters
my $nnodes = "null";    # number of cluster nodes
my $queuename;    # name of the queue to submit the job to
my $queuesys;     # name of the queue to submit the job to
my $parallelism;  # "serial" or "parallel"
my $account;      # name of the account to take the hours from
my $adcircdir;    # directory where the padcirc executable is found
my $scriptdir;    # directory where the asgs executables are stored
my $advisdir;     # directory for the individual advisory
my $inputdir;     # directory where the template files are stored
my $scenario;     # name of the ensemble member (nowcast, storm3, etc)
my $notifyuser;   # email address of the user to be notified in case of error
my $submitstring; # string to use to submit a job to the parallel queue
my $walltime;     # estimated maximum wall clock time
my $wallminutes;  # integer number of minutes, calculated from HH:MM:SS
my $qscripttemplate; # template file to use for the queue submission script
my $qscript;      # queue submission script we're producing
my $syslog;       # the log file that the ASGS uses
my $ppn;          # the number of processors per node
my $qos = "null"; # quality of service
my $cloptions=""; # command line options for adcirc, if any
my $jobtype;      # e.g., prep15, padcirc, padcswan, etc
my $localhotstart; # present if subdomain hotstart files should be written
my $cmd;           # the command line to execute
my $reservation="null"; # name of SLURM reservation where the job should be submitted
my $constraint="null";  # name of SLURM constraint the job should use
my $cmd="null";         # command to be executed
my $numwriters=0;        # number of writer processors, if any
my $joblauncher = "null"; # executable line in qscript (ibrun, mpirun, etc)
our %properties;     # holds the run.properties file
our $this="qscript.pl";
# initialize to the log file that adcirc uses, just in case
our $syslog="scenario.log";
our $cyclelog="../cycle.log";
our $scenariolog="scenario.log";
#
GetOptions("jobtype=s" => \$jobtype );
#
#-----------------------------------------------------------------
#
#       R E A D   R U N . P R O P E R T I E S   F I L E
#
#-----------------------------------------------------------------
if ( -e "run.properties" ) {
   unless (open(RP,"<run.properties")) {
      print STDERR "ERROR: Found the run.properties file but could not open it: $!.";
      die;
   }
} else {
   print STDERR "ERROR: The run.properties file was not found.";
   die;
}
while (<RP>) {
   chomp;
   # use first ":" to allow hashes to have : embedded in value (but not key)
   my $sep = index($_,":");
   my $k = substr($_,0,$sep);  # key
   my $v = substr($_,$sep+1);  # value
   # strip leading and trailing spaces
   $k =~ s/^\s+//g;
   $k =~ s/\s+$//g;
   $v =~ s/^\s+//g;
   $v =~ s/\s+$//g;
   $properties{$k} = $v
}
close(RP);
#-----------------------------------------------------------------
#
#                S E T   P A R A M E T E R S
#
#-----------------------------------------------------------------
$cloptions = "";
# get path to adcirc executables
$adcircdir = $properties{"path.adcircdir"};
# get path to asgs executables
$scriptdir = $properties{"path.scriptdir"};
# type of queueing system
$queuesys = $properties{"hpc.queuesys"};
# determine whether this is a parallel job
$parallelism = $properties{"hpc.job.$jobtype.parallelism"};
# get the scenario log file
$scenariolog = $properties{"monitoring.logging.file.scenariolog"};
# get number of processors per node
$ppn = $properties{"hpc.job.$jobtype.ppn"};
# get quality of service if any
#
# construct command line for running adcprep or serial job
if ( $parallelism eq "serial" ) {
   $totalcpu = 1; # these are serial jobs
   $nnodes = 1;   # these are serial jobs
   if ( $jobtype eq "partmesh" || $jobtype =~ /prep/ ) {
      # get number of compute cpus
      $ncpu = $properties{"hpc.job.$jobtype.for.ncpu"}; # for adcprep
      $cmd="$adcircdir/adcprep --np $ncpu --$jobtype --strict-boundaries";
   } else {
      $cmd = $properties{"hpc.job.$jobtype.cmd"};
   }
   # FIXME: this is a hack to handle an idiosyncracy in ppn on queenbee and supermic
   # when a priority queue is used
   my $serqueue = $properties{"hpc.job.$jobtype.serqueue"};
   my $hpcenvshort = $properties{"hpc.hpcenvshort"};
   if ( $serqueue eq "priority" && ( $hpcenvshort eq "queenbee" || $hpcenvshort eq "supermic" ) ) {
      $ppn = 20;
   }
}
#
# construct command line for running padcirc, padcswan, or other parallel job
if ( $jobtype eq "padcirc" || $jobtype eq "padcswan" ){
   # get number of compute cpus
   $ncpu = $properties{"hpc.job.$jobtype.ncpu"};
   # set subdomain hotstart files if specified
   if ( $properties{"adcirc.hotstartcomp"} eq "subdomain" ) {
      $cloptions .= "-S -R";
   }
   # set dedicated writer processors
   $numwriters = $properties{"hpc.job.$jobtype.numwriters"};
   if ( $numwriters != 0 ) {
      $cloptions = $cloptions . " -W " . $numwriters;
      $totalcpu = $ncpu + $numwriters;
   } else {
      $totalcpu = $ncpu;
   }
   # determine number of compute nodes to request
   if ( $ppn ne "null" ) {
      $nnodes = int($totalcpu/$ppn);
      if ( ($totalcpu%$ppn) != 0 ) {
         $nnodes++;
      }
   } else {
      $nnodes = "null";
   }
   $joblauncher = $properties{"hpc.joblauncher"};
   # fill in template positions in job launcher line
   $joblauncher =~ s/%ncpu%/$ncpu/g;
   $joblauncher =~ s/%totalcpu%/$totalcpu/g;
   $joblauncher =~ s/%nnodes%/$nnodes/g;
   $cmd="$joblauncher $adcircdir/$jobtype $cloptions";
}
#
# compute wall clock time HH:MM:SS in minutes
$walltime = $properties{"hpc.job.$jobtype.limit.walltime"};
$walltime =~ /(\d+):(\d+):(\d+)/;
$wallminutes = $1*60 + $2;
#
# get queue script template
$qscripttemplate = $properties{"hpc.job.$jobtype.file.qscripttemplate"};
#
# set name of qscript
my $queuesyslc = lc $queuesys;
$qscript = $jobtype . "." . $queuesyslc;
#
#-----------------------------------------------------------------
#
#              F I L L   I N   T E M P L A T E
#
#-----------------------------------------------------------------
if ( -e $qscripttemplate ) {
   unless (open(TEMPLATE,"<$qscripttemplate")) {
      print STDERR "Found the $qscripttemplate template file but could not open it: $!.";
      die;
   }
} else {
   print STDERR "ERROR: The $qscripttemplate template file was not found.";
   die;
}
unless (open(QSCRIPT,">$qscript")) {
   print STDERR "Could not create the $qscript file: $!.";
   die;
}
#
while(<TEMPLATE>) {
    # remove queue system directives from queueing systems other than
    # the one specified and then fill in the correct environment
    # variables for the queue system we ar using
    if ( $queuesys eq "PBS" ) {
       s/#SBATCH/null/g;
       s/%JOBID%/PBS_JOBID/g;
       s/%JOBDIR%/PBS_O_WORKDIR/g;
       s/%JOBHOST%/PBS_O_HOST/g;
       s/%JOBNODES%/"`cat \$PBS_NODEFILE`"/g;  # PBS var contains name of node list file
       s/%JOBNNODES%/PBS_NUM_NODES/g;
       s/%JOBNTASKSPERNODE%/PBS_NUM_PPN/g;
       s/%JOBNTASKS%/PBS_TASKNUM/g;
    }
    if ( $queuesys eq "SLURM" ) {
       s/#PBS/null/g;
       s/%JOBID%/SLURM_JOBID/g;
       s/%JOBDIR%/SLURM_SUBMIT_DIR/g;
       s/%JOBHOST%/SLURM_SUBMIT_HOST/g;
       s/%JOBNODES%/\$SLURM_JOB_NODELIST/g;  # SLURM var contains node list
       s/%JOBNNODES%/SLURM_NNODES/g;
       s/%JOBNTASKSPERNODE%/SLURM_NTASKS_PER_NODE/g;
       s/%JOBNTASKS%/SLURM_NTASKS/g;
    }
    # fill in the lower case name of the queueing system
    s/%queuesyslc%/$queuesyslc/g;
    # fill in the name of the queueing system (typicall upper case in the
    # run.properties file
    s/%queuesys%/$queuesys/g;
    # fill in the number of compute cores (i.e., not including writers)
    s/%ncpu%/$ncpu/;
    # number of cores per compute node
    s/%ppn%/$ppn/;
    # fill in the total number of cores
    s/%totalcpu%/$totalcpu/;
    # the estimated amount of wall clock time
    if ( $properties{"hpc.walltimeformat"} eq "minutes" ) {
       s/%walltime%/$wallminutes/;
    } else {
       s/%walltime%/$walltime/;
    }
    # name of the account to take the hours from
    s/%account%/$properties{"hpc.job.$jobtype.account"}/;
    # directory where adcirc executables are located
    s/%adcircdir%/$properties{"path.adcircdir"}/;
    # directory where asgs executables are located
    s/%scriptdir%/$properties{"path.scriptdir"}/;
    # directory for this particular advisory
    s/%advisdir%/$properties{"path.advisdir"}/;
    # name of this member of the ensemble (nowcast, storm3, etc)
    s/%scenario%/$properties{"scenario"}/g;
    # name of overall asgs log file
    s/%syslog%/$properties{"monitoring.logging.file.syslog"}/g;
    # fill in command line options
    s/%cloptions%/$cloptions/;
    # fill in command to be executed
    s/%cmd%/$cmd/;
    # the type of job that is being submitted (partmesh, prep15, padcirc, etc)
    s/%jobtype%/$jobtype/g;
    # the email address of the ASGS Operator
    if ( $properties{"notification.emailnotify"} eq "yes" ) {
       s/%notifyuser%/$properties{"notification.hpc.email.notifyuser"}/g;
    } else {
       s/%notifyuser%/null/g;
    }
    if ( $queuesys eq "SLURM" ) {
       # the SLURM reservation
       s/%reservation%/$properties{"hpc.slurm.job.$jobtype.reservation"}/g;
       # the SLURM constraint
       s/%constraint%/$properties{"hpc.slurm.job.$jobtype.constraint"}/g;
       # partition is not here b/c it is synonym for queuename
       #
       # fill in command to be executed
       $qos = $properties{"hpc.slurm.job.$jobtype.qos"};
       unless ( defined $qos ) {
          $qos = "null";
       }
       s/%qos%/$qos/g;
    }
    # fills in the number of nodes on platforms that require it
    s/%nnodes%/$nnodes/g;
    # fill in serial queue
    if ( $parallelism eq "serial" ) {
       # name of the queue on which to run
       s/%queuename%/$properties{"hpc.job.$jobtype.serqueue"}/;
    }
    # fill in parallel queue
    if ( $parallelism eq "parallel" ) {
       # name of the queue on which to run
       s/%queuename%/$properties{"hpc.job.$jobtype.queuename"}/;
    }
    # copy non-null lines to the queue script
    unless ( $_ =~ /noLineHere/ || $_ =~ /null/ ) {
       print QSCRIPT $_;
    }
}
close(TEMPLATE);
close(QSCRIPT);
#
# record name of queue script to run.properties file
unless (open(RP,">>run.properties")) {
   print STDERR "ERROR: Could not open run.properties file: $!.";
   die;
}
print RP "hpc.job.$jobtype.file.qscript : $qscript\n";
close(RP);
