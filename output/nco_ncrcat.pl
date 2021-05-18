#!/usr/bin/env perl
#----------------------------------------------------------------
# nco_ncrcat.pl
#
# concatenate fort.61.nc files at various time spans to
# facilitate validation
#----------------------------------------------------------------
# Copyright(C) 2021 Jason Fleming
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
#----------------------------------------------------------------
# This script needs a "now" date in yyyymmddhh24 format and expects
# to find directories and files arranged in the following way for
# files posted to an opendap server:
# $root_data_dir/year/metmodel/yyyymmddhh24/mesh/hpc/asgs_instance/scenario/file
# and this way for files that are still in-situ in the directories
# of an asgs instance on the hpc machine:
# $root_data_dir/yyyymmddhh24/scenario/file
# For example:
#./2021/nam/2021012918/hsofs/hatteras.renci.org/hsofs-nam-bob-2021/nowcast/fort.61.nc
# or
# /work/jgflemin/asgs45806/2021042400/nowcast/fort.61.nc
# Then the script concatenates the output files over different time
# periods as follows (in days):
# 0.25 0.5 1.0 2.0 4.0 8.0 16.0 32.0
# with "now" date given as the final date in the file.
#----------------------------------------------------------------
# Assumptions :
#   1. all files have the same cold start date (so the time in
#      seconds is all that is needed)
#   2. if the target date is not given, the script uses the latest
#      target date available
#   3. the sort used in the find command assumes that the only
#      difference in the paths is in the dates ; if there are
#      other differences (e.g., hpcenv) the sort command will fail
#----------------------------------------------------------------
# Dependencies :
#   ncdump (installed with main netcdf library)
#   ncrcat (part of nco)
#   ncks   (part of nco?)
#----------------------------------------------------------------
use strict;
use warnings;
#use Date::Calc;
use Getopt::Long;
#
sub stderrMessage($$);
#
my $root_data_dir = ".";     # directory containing subdirectories with data of interest
my $datafile = "fort.61.nc"; # file containing data at each station
my $cold_start_date = "null";  # yyyymmddhh24 when the simulation was coldstarted; used to compute calendar dates/times
my $target_end_sec = "null"; # the end of the target data file in seconds
my $target_date = "null";    # yyyymmddhh24 DIRECTORY to count back from
my @datafiles_in_period;     # datafiles that fall between the target date and the longest time period
my $csy; my $csm; my $csd; my $csh; # cold start date components
my @time_periods = qw( 0.25 0.5 1.0 2.0 4.0 8.0 16.0 32.0 );
my @time_period_prefixes = qw( 6_hours 12_hours 1_day 2_days 4_days 8_days 16_days 32_days );
my @files_of_interest;       # list of files to concatenate
my $insitu=0;                # files are still on local hpc (rather than posted to opendap)
#
GetOptions(
           "root-data-dir=s" => \$root_data_dir,
           "in-situ" => \$insitu,
           "target-date=s" => \$target_date
          );
#
# find the paths to the files ... the find command does not seem to return them
# in ascending order so they are sorted ... only want the nowcast or
# hindcast scenarios for use in validation
my @files = `find $root_data_dir -name $datafile -print | grep -E 'nowcast|hindcast' | sort`;
foreach my $f (@files) {
   #stderrMessage("DEBUG","$f");
}
#
# check to see if the initialize/hindcast scenario is present; if so,
# sort will make it the "latest" scenario but we want it to be earliest
my @path_parts = split("/",$files[-1]);
foreach my $p (@path_parts) {
   #stderrMessage("DEBUG","$p");
}
#stderrMessage("DEBUG","path_parts[-2] is $path_parts[-2]");
if ( $path_parts[-2] eq "hindcast" ) {
   my $hindcast_scenario = pop(@files);
   unshift(@files,$hindcast_scenario);
}
#
# now reverse the order so it is reverse chronological
my @reverse_files = reverse(@files);
#
# find the final or target date if it was not given
if ( $target_date eq "null" ) {
   my $target_path = $reverse_files[0];
   print "target_path is $target_path\n";
   # remove the part of the path that precedes the target directory
   my $sub_target_path = substr($target_path,length($root_data_dir));
   print "sub_target_path is $sub_target_path\n";
   my @target_path_parts = split("/", $sub_target_path) ;
   $target_date = $target_path_parts[3];
}
print "target_date is $target_date\n";
#
# go through the list of files and build up the
# concatenated file
my @files_in_period;
my $datePathLocation = 3; # true if the files were posted to opendap server
if ( $insitu ) {
   $datePathLocation = 0; # true if the files are still on the hpc
}
foreach my $f (@reverse_files) {
    my $sub_target_path = substr($f,length($root_data_dir));
    stderrMessage("DEBUG","sub_target_path $sub_target_path");
    my @target_path_parts = split("/", $sub_target_path) ;
    foreach my $p (@target_path_parts) {
        #stderrMessage("DEBUG","$p");
     }
    # if the sub_target_path starts with / then the
    # first element of @target_path_parts will be empty
    if ( $target_path_parts[0] eq "" ) {
        shift(@target_path_parts);
    }
    # skip files in the list that are later than the target date
    stderrMessage("DEBUG","target_path_parts[datePathLocation] > target_date ... $target_path_parts[$datePathLocation] > $target_date");
    if ( $target_path_parts[$datePathLocation] > $target_date ) {
        next;
    }
    # add this file to the list of files of interest (this list is in chronological order)
    chomp($f);
    unshift(@files_of_interest,$f);
    #
    # determine the final time in seconds in the target data file
    # if this has not been done already
    if ( $target_end_sec eq "null" ) {
        # use netcdf kitchen sink utility to get the final time in seconds
        # also grab the coldstartdate while we're at it
        my @timelines = `ncks -v time -d time,-1 $f`;
        foreach my $tl (@timelines) {
            if ( $tl =~ /time:base_date = "(\d\d\d\d)-(\d\d)-(\d\d) (\d\d)\:(\d\d)\:(\d\d)"/ ) {
                $cold_start_date = $1 . $2 . $3 . $4;
                $csy = $1 ; $csm = $2 ; $csd = $3 ; $csh = $4;
                # FIXME: we're assuming all files have the same cold start date
                print "cold start date is $cold_start_date\n";
            }
            if ( $tl =~ /time = (\d+)/ ) {
                $target_end_sec = $1;
                print "target_end_sec is $target_end_sec\n";
            }
        }
    }
    #
    # determine time in seconds at the start of the file of interest
    my $this_file_start_sec;
    my @timelines = `ncks -v time -d time,1 $f`;
    foreach my $tl (@timelines) {
        if ( $tl =~ /time = (\d+)/ ) {
            $this_file_start_sec = $1;
            print "this_file_start_sec is $this_file_start_sec\n";
            last;
       }
    }
    # get the start of the current time period of interest in seconds
    my $this_period_start_sec = $target_end_sec - ($time_periods[0] * 86400.0);
    # check to see if this data file starts before the period of interest,
    # and if so, concatenate the list of files we have so far
    # for this time period and write it out
    # FIXME: this will probably result in concatenating too much data,
    # at least sometimes
    if ( $this_file_start_sec < $this_period_start_sec ) {
        my $period_file_list = join(" ",@files_of_interest);
        #stderrMessage("DEBUG","period_file_list $period_file_list");
        my $period_file_name = $time_period_prefixes[0] . "_fort.61.nc";
        # -O will overwrite an existing file
        # -D 0 will set the debug level to 0 and hopefully suppress spurious warnings
        system("ncrcat -O -D 0 $period_file_list $period_file_name");
        #stderrMessage("DEBUG","system(ncrcat $period_file_list $period_file_name)");
        # go to the next period
        shift(@time_periods);
        shift(@time_period_prefixes);
    }
    # end when we run out of time periods to write values for
    if ( @time_periods == 0 ) {
        last;
    }
}
#
#-----------------------------------------------------------------
#       F U N C T I O N    S T D E R R  M E S S A G E
#-----------------------------------------------------------------
sub stderrMessage ($$) {
   my $level = shift;
   my $message = shift;
   my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
   (my $second, my $minute, my $hour, my $dayOfMonth, my $month, my $yearOffset, my $dayOfWeek, my $dayOfYear, my $daylightSavings) = localtime();
   my $year = 1900 + $yearOffset;
   my $theTime = "[$year-".sprintf("%3s",$months[$month])."-".sprintf("%02d",$dayOfMonth)."-T".sprintf("%02d",$hour).":".sprintf("%02d",$minute).":".sprintf("%02d",$second)."]";
   printf STDERR "$theTime $level: nco_ncrcat.pl: $message\n";
}
