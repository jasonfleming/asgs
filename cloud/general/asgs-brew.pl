#!/usr/bin/perl

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

# NOTE: this is meant to run using any perl that is available
# on a system, it should only rely on core Perl modules

use strict;
use warnings;
use Getopt::Long qw(GetOptionsFromArray);
use Cwd        ();
use File::Copy ();
use File::Path ();

package local::asgs_brew;

use constant EXIT_SUCCESS => 0;
use constant EXIT_DIE     => 255;

# do not run if inside of asgsh
if ( defined $ENV{_ASGSH_PID} ) {
    print qq/\nOops!\nPlease run outside of the asgsh environment.\n`exit` from asgsh (pid: $ENV{_ASGSH_PID}) and run again\n/;
    exit EXIT_DIE;
}

# copy existing environment
local %ENV = %ENV;

# precondition the shell's environmental variables
__PACKAGE__->_init_env( \%ENV );

our $AFFECTED_ENV_VARS = {};    # list of envars that were updated across all steps
our $SKIP_STEPS_LIST   = {};    # for debugging only, forces a step's "skip_if" to be true

exit __PACKAGE__->run( \@ARGV // [] ) if not caller;

# basic constructor, just for testing at this time
sub new {
    my $pkg  = shift;
    my $self = {};
    bless $self, $pkg;
    return $self;
}

sub _get_help {
    return qq{
Usage:

    $0 --machinename <MachineName> --compiler <CompilerFamily> --asgs-profile <ProfileName> [ --install-path some/path --home /path/other/than/user/\$HOME --force --clean [ --list-steps | --skip-steps | --run-steps ] ]

Required Flags:

    --compiler, --machinename, --asgs-profile

Reset asgsh with clean environment:

    $0 --machinename <MachineName> --compiler <CompilerFamily> --asgs-profile <ASGSProfileName> --run-steps setup-env

More Help and Information:

    \$ perldoc $0 

Note:

    --install-path if not specified defaults to \$WORK/opt, then \$HOME/opt (respects the '--home' flag)

};
}

sub run {
    my ( $self, $args_ref ) = @_;

    # initial defaults (more are set dynamically after Getopts, in _munge_option_defaults)
    my $opts_ref = {

        # note: 'adcirc-dir' is finalized in _parse_options after ASGS_HOME is determined
        'adcirc-git-branch' => q{v53release},
        'adcirc-git-url'    => q{git@github.com:adcirc},    # ssh keys required for adcirc
        'adcirc-git-repo'   => q{adcirc-cg},
        brewflags           => join( q{ }, @$args_ref ),
        compiler            => q{gfortran},
        'make-jobs'         => 1,
        scriptdir           => Cwd::getcwd(),               # fixed throughout, no option to changes this
    };

    $self->_parse_options( $args_ref, $opts_ref );    # exits with 255 if error with options
    $self->_prerun_steps($opts_ref);                  # do things before steps are run
    $self->_run_steps($opts_ref);                     # bulk of time spent running the 'run steps'
    $self->_install_asgs_shell($opts_ref);            # finalizes installation by installing/updating asgsh

    return EXIT_SUCCESS;
}

sub _init_env {
    my ( $self, $ENV_ref ) = @_;
    for my $envar (qw/PERL5LIB PERL_MB_OPT PERL_LOCAL_LIB_ROOT PERL_MM_OPT/) {
        delete $ENV_ref->{$envar};
    }
    return;
}

sub _parse_options {
    my ( $self, $args_ref, $opts_ref ) = @_;

    my @flags = (
        qw/
          adcirc-dir=s
          adcirc-git-branch=s
          adcirc-git-url=s
          adcirc-git-repo=s
          build-adcirc
          clean
          compiler=s
          debug
          force
          home
          install-path=s
          list-steps
          machinename=s
          make-jobs=i
          asgs-profile=s
          replace-home
          run-steps=s
          skip-steps=s
          update-shell
          /
    );

    local $@;
    my $ret = Getopt::Long::GetOptionsFromArray( $args_ref, $opts_ref, @flags );

    my $errmsg;
    if ( not $ret ) {
        $errmsg = qq{An unrecognized option was passed\n};
    }
    elsif ( not $opts_ref->{compiler} or not $opts_ref->{machinename} ) {
        $errmsg = qq{--compiler and --machinename flags are required};
    }
    elsif ( not $opts_ref->{'asgs-profile'} ) {
        $errmsg = qq{--asgs-profile is not set, this is required to differentiate among different ASGS installations.\n\nNote: ASGS Shell looks for a profile called 'default' to load automatically on start.};
    }
    elsif ( $opts_ref->{'skip-steps'} and $opts_ref->{'run-steps'} ) {
        $errmsg = qq{--skip-steps can't be used with --run-steps};
    }

    $self->_munge_option_defaults($opts_ref);    # final chance to set defaults

    if ($errmsg) {
        print qq{\n$errmsg\n};
        print $self->_get_help();
        exit EXIT_DIE;                           # die's exit code
    }

    return;
}

sub _munge_option_defaults {
    my ( $self, $opts_ref ) = @_;

    # default to effective user's $HOME
    if ( not $opts_ref->{home} ) {
        $opts_ref->{home} = ( getpwuid $> )[7];
    }

    # otherwise, force $HOME in the process' environment to use
    # a custom value of for $HOME
    else {
        # sanity check, anything defined by --home must already exist
        die qq/$opts_ref->{home} must exist to proceed. Please create it manually.\n/ if not -d $opts_ref->{home};

        # set this is $HOME in the current environment (catch-all) if --replace-home is used (experimental)
        $ENV{HOME} = $opts_ref->{home} if $opts_ref->{'replace-home'};
    }

    # post Getopt defaults, in case user has set a new 'home' with --home
    my $asgs_home       = $opts_ref->{home};
    my $adcirc_git_repo = $opts_ref->{'adcirc-git-repo'};
    $opts_ref->{'adcirc-dir'}   = $opts_ref->{'adcirc-dir'}   // qq{$asgs_home/$adcirc_git_repo};     # 'adcirc-cg' is the upstream repo name
    $opts_ref->{'install-path'} = $opts_ref->{'install-path'} // $ENV{WORK} // qq{$asgs_home/opt};    # if $WORK is defined in environment, use it as install-path base
    $opts_ref->{'install-path'} = sprintf( "%s/%s", $opts_ref->{'install-path'}, $opts_ref->{'asgs-profile'} );
    return;
}

sub _prerun_steps {
    my ( $self, $opts_ref ) = @_;

    # determine run steps
    if ( $opts_ref->{'skip-steps'} ) {
        for my $step ( split ',', $opts_ref->{'skip-steps'} ) {
            ++$SKIP_STEPS_LIST->{$step};
        }
    }
    elsif ( $opts_ref->{'run-steps'} ) {
        foreach my $step_ref ( @{ $self->get_steps($opts_ref) } ) {
            ++$SKIP_STEPS_LIST->{ $step_ref->{key} };
        }
        for my $step ( split ',', $opts_ref->{'run-steps'} ) {
            delete $SKIP_STEPS_LIST->{$step};
        }
    }
    return;
}

sub _run_steps {
    my ( $self, $opts_ref ) = @_;
    my $start_dir = $opts_ref->{scriptdir};

  LIST_STEPS:
    if ( $opts_ref->{'list-steps'} ) {
        foreach my $op ( @{ $self->get_steps($opts_ref) } ) {
            die q{Steps require a 'key' and a 'description' field for --list-steps to work properly} if not $op->{key} or not $op->{description};
            print sprintf( "% 20s - %s\n", $op->{key}, $op->{description} );
        }

        # proceeds no further if --list-steps is used
        return 0;
    }
  RUN_STEPS:
    foreach my $op ( @{ $self->get_steps($opts_ref) } ) {
        print $op->{name} . qq{\n} if defined $opts_ref->{debug};

        # start in known location (step pwd can be relative)
        chdir $start_dir;

        # move to specified directory
        chdir $op->{pwd};

        # augment ENV based on $op->{export_ENV}
        $self->_setup_ENV( $ENV, $op, $opts_ref );
        next RUN_STEPS if $opts_ref->{'update-shell'};

        # check for skip condition for run step, unless --force or --clean is used
        # if op is contained in --skip-steps list then the step is skipped unconditionally (--force is ignored)
        if ( defined $SKIP_STEPS_LIST->{ $op->{key} } or ( ref $op->{skip_if} eq q{CODE} and $op->{skip_if}->( $op, $opts_ref ) and not $opts_ref->{force} and not $opts_ref->{clean} ) ) {
            print qq{Skipping $op->{name} because 'skip_if' condition has been met.\n} if defined $opts_ref->{debug};
            next RUN_STEPS;
        }

        # precondition checking needs to be more robust and more clearly
        # defined (i.e., what to do on failure for subsequent runs
        # check is skipped if --clean is passed
        if ( not $self->_run_precondition_check ) {
            die qq{pre condition for "$op->{name}" FAILED, stopping. Please fix and rerun.\n};
        }

        # run command or clean (looks for --clean)
        my $exit_code = $self->_run_command( $op, $opts_ref );

        # always expects a clean exit code (value of 0) from the command, a command that doesn't return one
        # is probably faulty in some way
        die qq{command for "$op->{name}" exited with an error code of $exit_code, stopping. Please fix and rerun.\n} if !defined $exit_code or $exit_code > 0;

        # verify step completed successfully
        # check is skipped if --clean is passed
        if ( $self->_run_postcondition_check( $op, $opts_ref ) ) {
            print qq{"$op->{name}" was completed successfully\n} if defined $opts_ref->{debug};
        }
        else {
            die qq{post condition for "$op->{name}" FAILED, stopping. Please fix and rerun.\n};
        }
    }
    return 1;
}

sub _run_precondition_check {
    my ( $self, $op, $opts_ref ) = @_;    # skips check if --clean or precondition check doesn't exist in step's definition as a CODE ref
    return 1
      if $opts_ref->{clean}
      or not ref $op->{precondition_check} eq q{CODE}
      or $op->{precondition_check}->( $op, $opts_ref );
    return undef;
}

sub _run_postcondition_check {
    my ( $self, $op, $opts_ref ) = @_;

    # skips check if --clean or postcondition check doesn't exist in step's definition as a CODE ref
    return 1
      if $opts_ref->{clean}
      or not ref $op->{postcondition_check} eq q{CODE}
      or $op->{postcondition_check}->( $op, $opts_ref );
    return undef;
}

# if this thing grows any larger, it'll have to be broken out into a separate
# file...
sub _install_asgs_shell {
    my ( $self, $opts_ref ) = @_;

    return 1 if $opts_ref->{'list-steps'} or $opts_ref->{clean};    # do not show

    my $asgs_install_path = $opts_ref->{'install-path'};
    my $asgs_home         = $opts_ref->{home};
    my $asgs_machine_name = $opts_ref->{machinename};
    my $asgs_compiler     = $opts_ref->{compiler};
    my $scriptdir         = $opts_ref->{scriptdir};
    my $profile           = $opts_ref->{'asgs-profile'};
    my $env_summary       = $self->_get_env_summary($opts_ref);
    my $asgs_meta_dir     = $ENV{ASGS_META_DIR};

    # create the registry for ASGS profiles if it doesn't
    # already exist
    if ( !-e qq{$asgs_meta_dir} ) {
        mkdir qq{$asgs_meta_dir};
    }

    # dump the full environment into a named profile
    # NOTE: overwrites anything that is there of the name
    open my $fh, q{>}, qq{$asgs_meta_dir/$profile} || die $!;
    print $fh $env_summary;
    close $fh;

    # this file supplies the functionality of asgsh
    my $rcfile_src = q{./cloud/general/DOT-asgs-brew.sh};
    my $rcfile     = qq{$asgs_home/.asgs-brew.sh};
    if ( -e $rcfile_src ) {
        File::Copy::copy( $rcfile_src, $rcfile );
    }

    # create/update $asgs_home/bin/asgsh
    my $asgs_home_bin = qq{$asgs_home/bin};
    if ( !-e qq{$asgs_home_bin} ) {
        mkdir qq{$asgs_home_bin};
    }
    my $file = qq{$asgs_home_bin/asgsh};
    open $fh, q{>}, $file or die qq{failed to create $file: $!};
    print $fh $self->_get_asgsh( $opts_ref, $rcfile );
    chmod 0750, $file;
    close $fh;

    # prints to STDOUT after asgs-brew.pl successfully completes
    print qq{
The ASGS shell has been updated.

Quick Start:

   $file

Recommended Start:

Adding the following line to your $asgs_home/.bash_profile file to preserve
the change on subsequent logins:

   export PATH=\$PATH:$asgs_home_bin

Source it:

   . $asgs_home/.bash_profile

Then run the shell:

   asgsh

If you didn't optionally build ADCIRC, the you can do so using the guided
utility available under asgsh, 'initadcirc'

NOTE:
Once this is run, you may assume the above environment is available. This
can be tested by making sure the exected binaries are in your path, for
example, `which ncdump` should find the utility in $asgs_install_path/bin

To report bugs or request enhancements, please file them at

   https://github.com/jasonfleming/asgs/milestone/19

Happy ASGS'ing.

};
    return 1;
}

sub _get_asgsh {
    my ( $self, $opts_ref, $rcfile ) = @_;
    my $asgs_install_path   = $opts_ref->{'install-path'};
    my $asgs_home           = $opts_ref->{home};
    my $asgs_machine_name   = $opts_ref->{machinename};
    my $asgs_compiler       = $opts_ref->{compiler};
    my $scriptdir           = $opts_ref->{scriptdir};
    my $env_summary         = $self->_get_env_summary($opts_ref);
    my $_asgs_exported_vars = join( q{ }, keys %$AFFECTED_ENV_VARS );

    return qq{#!/usr/bin/env bash
# xxx THIS FILE IS GENERATED BY asgs-brew.pl                                           xxx
# xxx DO NOT CUSTOMIZE THIS FILE, IT WILL BE OVERWRITTEN NEXT TIME asgs-brew.pl IS RUN xxx
# 
# Update shell by adding "--update-shell" flag to the asgs-brew.pl command used to build this
# environment:
#     ./asgs-brew.pl --compiler-$asgs_compiler --machinename=$asgs_machine_name --install-path=$asgs_install_path --update-shell

if [ -n "\$_ASGSH_PID" ]; then
  echo
  echo "Do not nest asgsh. To restart asgsh, type 'exit' then 'asgsh'."
  echo
  exit 1
fi

# process options passed directly to `asgsh`
options=\$(getopt -u -o "dhp:x" -- "\$@")
eval set -- "\$options"
while true
  do
    case \$1 in
      -d) set -x
          export _asgs_debug_mode=1
          ;;
      -h)
        echo "\nInteractive ASGS Shell Environment\n\nUsage:\n\tasgsh [-h] | [-d] [-p PROFILE-NAME] [-x]\n"
        exit 1
        ;;
      -p) 
        shift
        export profile=\$1
        ;;
      -x)
        export skip_platform_profiles=1
        ;;
      --)
        shift
        break;;
    esac
    shift
done

clear
echo
echo "               AAA                 SSSSSSSSSSSSSSS         GGGGGGGGGGGGG   SSSSSSSSSSSSSSS "
echo "              A:::A              SS:::::::::::::::S     GGG::::::::::::G SS:::::::::::::::S"
echo "             A:::::A            S:::::SSSSSS::::::S   GG:::::::::::::::GS:::::SSSSSS::::::S"
echo "            A:::::::A           S:::::S     SSSSSSS  G:::::GGGGGGGG::::GS:::::S     SSSSSSS"
echo "           A:::::::::A          S:::::S             G:::::G       GGGGGGS:::::S            "
echo "          A:::::A:::::A         S:::::S            G:::::G              S:::::S            "
echo "         A:::::A A:::::A         S::::SSSS         G:::::G               S::::SSSS         "
echo "        A:::::A   A:::::A         SS::::::SSSSS    G:::::G    GGGGGGGGGG  SS::::::SSSSS    "
echo "       A:::::A     A:::::A          SSS::::::::SS  G:::::G    G::::::::G    SSS::::::::SS  "
echo "      A:::::AAAAAAAAA:::::A            SSSSSS::::S G:::::G    GGGGG::::G       SSSSSS::::S "
echo "     A:::::::::::::::::::::A                S:::::SG:::::G        G::::G            S:::::S"
echo "    A:::::AAAAAAAAAAAAA:::::A               S:::::S G:::::G       G::::G            S:::::S"
echo "   A:::::A             A:::::A  SSSSSSS     S:::::S  G:::::GGGGGGGG::::GSSSSSSS     S:::::S"
echo "  A:::::A               A:::::A S::::::SSSSSS:::::S   GG:::::::::::::::GS::::::SSSSSS:::::S"
echo " A:::::A                 A:::::AS:::::::::::::::SS      GGG::::::GGG:::GS:::::::::::::::SS"
echo "AAAAAAA                   AAAAAAASSSSSSSSSSSSSSS           GGGGGG   GGGG SSSSSSSSSSSSSSS"
echo
echo "    d888b  d88  d888b  d88  d888b  d88  d888b  d88  d888b  d88  d888b  d88  d888b  d88"
echo "    d888b  d88  d888b  d88  d888b  d88  d888b  d88  d888b  d88  d888b  d88  d888b  d88"
echo "   d888888888P d888888888P d888888888P d888888888P d888888888P d888888888P d888888888P"
echo "   88P  Y888P  88P  Y888P  88P  Y888P  88P  Y888P  88P  Y888P  88P  Y888P  88P  Y888P"
echo

# xxx THIS FILE IS GENERATED BY asgs-brew.pl                                           xxx
# xxx DO NOT CUSTOMIZE THIS FILE, IT WILL BE OVERWRITTEN NEXT TIME asgs-brew.pl IS RUN xxx
 
# denotes we're in an active asgsh session
export _ASGSH_PID=\$\$

# denotes which environmental variables we care about when saving a profile - includes variables that
# are meaningful to ASGS Shell, but not set in asgs-brew.pl
export _ASGS_EXPORTED_VARS="$_asgs_exported_vars _ASGS_EXPORTED_VARS WORK SCRATCH EDITOR PROPERTIESFILE INSTANCENAME RUNDIR SYSLOG ASGS_CONFIG ADCIRC_MAKE_CMD SWAN_UTIL_BINS_MAKE_CMD ADCSWAN_MAKE_CMD ADCIRC_BINS SWAN_UTIL_BINS ADCSWAN_BINS"
$env_summary

# export opts for processing in $rcfile
export _ASGS_OPTS="\$@"

# starts up bash with the environment created by asgs-brew.pl, sets the to "asgs> " so we know
# we're in the ASGS environment
exec bash --rcfile "$rcfile"

# xxx THIS FILE IS GENERATED BY asgs-brew.pl                                           xxx
# xxx DO NOT CUSTOMIZE THIS FILE, IT WILL BE OVERWRITTEN NEXT TIME asgs-brew.pl IS RUN xxx
};
}

sub _run_command {
    my ( $self, $op, $opts_ref ) = @_;
    my $asgs_compiler     = $opts_ref->{compiler};
    my $asgs_install_path = $opts_ref->{'install-path'};

    # choose command to run
    my $command = ( not $opts_ref->{clean} ) ? $op->{command} : $op->{clean};

    # short circuit if command is not defined
    return 0 if not defined $command;

    # choose how to run it
    my $type = ref $command;

    # supports both string commands (run via system) and anonymous subroutines
    my $exit_code = 0;
    if ( q{CODE} eq $type ) {
        local $@;
        my $ret = eval { $command->( $op, $opts_ref ); 1 };
        $exit_code = !defined $ret;    # expecting POSIX style code where 0 is success, non-zero is an error
    }
    elsif ( q{} eq $type ) {
        local $| = 1;
        local $?;
        print qq{\n$command\n};
        system("$command 2>&1");
        $exit_code = ( $? >> 8 );      # captures child process exit code
    }

    return $exit_code;
}

sub _get_env_summary {
    my ( $self, $opts_ref ) = @_;

    return undef if $opts_ref->{clean};

    my $summary = q{};
    foreach my $envar ( keys %$AFFECTED_ENV_VARS ) {
        $summary .= sprintf( qq{export %s=%s\n}, $envar, $ENV{$envar} // q{} );
    }

    return $summary;
}

sub _setup_ENV {
    my ( $self, $ENV, $op, $opts_ref ) = @_;

    # default separator
    my $default_separator = q{:};
    my $asgs_install_path = $opts_ref->{'install-path'};
  SETUP_ENV:
    foreach my $envar ( keys %{ $op->{export_ENV} } ) {
        next SETUP_ENV if not $op->{export_ENV}->{$envar};
        ++$AFFECTED_ENV_VARS->{$envar};    # track all environmental variables that are touched at least once

	# establish separator for available operations affecting envar, below
        my $separator = $op->{export_ENV}->{$envar}->{separator} // $default_separator;

	# value
        my $value = $op->{export_ENV}->{$envar}->{value} // q{};

	# remove new line, replace with a space (for cleaner definitions in "step" definitions)
	$value =~ s/\n//g;
	$value =~ s/ +/ /g;

        # default "how" mode is to prepend if the envar is already defined
        if ( not defined $op->{export_ENV}->{$envar}->{how} or $op->{export_ENV}->{$envar}->{how} eq q{prepend} ) {
            $ENV{$envar} = sprintf( "%s%s", $value, ( $ENV{$envar} ) ? $separator . $ENV{$envar} : q{} );
        }
        elsif ( $op->{export_ENV}->{$envar}->{how} eq q{append} ) {
            $ENV{$envar} = sprintf( "%s%s", ( $ENV{$envar} ) ? $ENV{$envar} . $separator : q{}, $value );
        }
        elsif ( $op->{export_ENV}->{$envar}->{how} eq q{replace} ) {
            $ENV{$envar} = $value;
        }
    }
    return 1;
}

# Note, user's environment is available via %ENV
# TODO - add in preconditions, need per step validation of required options/params
sub get_steps {
    my ( $self, $opts_ref ) = @_;

    my $scriptdir         = $opts_ref->{scriptdir};
    my $asgs_install_path = $opts_ref->{'install-path'};
    my $asgs_compiler     = $opts_ref->{compiler};
    my $asgs_home         = $opts_ref->{home};
    my $asgs_machine_name = $opts_ref->{machinename};
    my $makejobs          = $opts_ref->{'make-jobs'};
    my $brewflags         = $opts_ref->{brewflags};
    my $adcircdir         = $opts_ref->{'adcirc-dir'};
    my $adcirc_git_url    = $opts_ref->{'adcirc-git-url'} // q{git@github.com:adcirc};
    my $adcirc_git_branch = $opts_ref->{'adcirc-git-branch'};
    my $adcirc_git_repo   = $opts_ref->{'adcirc-git-repo'};
    my $pythonversion     = q{2.7.18};
    my $pythonpath        = qq{$asgs_install_path/python-$pythonversion};

    # generator for PATH string as an anonymous subroutine,
    #   Dev note: ADD new PATHs here using the existing pattern
    my $_get_all_paths = sub {
        my @all_paths = ();
        push @all_paths, ( qq{$asgs_install_path/bin}, qq{$scriptdir/cloud/general} );
        foreach my $dir (
            qw[
            bin
            my-bin
            cloud/general
            config
            config/tests
            input
            input/data_assimilation
            monitoring
            output
            output/cera_contour
            output/cpra_postproc
            output/cpra_postproc/MEX
            output/cpra_postproc/old/tools
            output/Cuba_post
            output/FG49
            output/NGOM_post
            output/PartTrack
            output/postProcessFlux
            output/POSTPROC_KMZGIS
            output/POSTPROC_KMZGIS/FigGen
            output/POSTPROC_KMZGIS/RenciGETools-10/src
            output/test
            output/TRACKING_FILES
            output/validation
            tides
            util
            util/admin
            util/input
            util/input/mesh
            util/input/nodalattr
            util/output
            util/troubleshooting
            ]
        ) {
            push @all_paths, sprintf( "%s/%s", $scriptdir, $dir );
        }
        my $path_string = join q{:}, @all_paths;
        return $path_string;
    };

    my $steps = [
        {
            key         => q{setup-env},
            name        => q{Initializes common environmental variables needed for subsequent steps in asgs-brew.pl.},
            description => q{Updates current environment with variables needed for subsequent steps. It only affects the environment within the asgs-brew.pl environment.},
            pwd         => q{./},
            command     => sub { 1 },
            clean       => sub {
                my ( $op, $opts_ref ) = @_;

                # export_ENV for run steps are used before 'clean' is run, so these are available
                File::Path::rmtree( $ENV{ASGS_META_DIR}, $ENV{ADCIRC_META_DIR}, { safe => 1 } );
                unlink qq{$asgs_home/.asgs-brew.sh}, qq{$asgs_home/bin/asgsh}, qq{$asgs_home/bin/update-asgs};
            },

            # augment existing %ENV (cumulative)
            export_ENV => {
                PATH               => { value => $_get_all_paths->(), how => q{prepend} },                       # prefer ASGS binaries and tools; full list managed above
                WORK               => { value => $ENV{WORK}    // q{}, how => q{replace} },                      # standardize across all platforms
                SCRATCH            => { value => $ENV{SCRATCH} // q{}, how => q{replace} },                      # standardize across all platforms
                LIBRARY_PATH       => { value => qq{$asgs_install_path/lib},             how => q{prepend} },    # for use by linkers
                LD_LIBRARY_PATH    => { value => qq{$asgs_install_path/lib},             how => q{prepend} },    # for use by linkers
                LD_RUN_PATH        => { value => qq{$asgs_install_path/lib},             how => q{prepend} },    # for use by binaries
                LD_INCLUDE_PATH    => { value => qq{$asgs_install_path/include},         how => q{prepend} },    # for use by compilers
                SCRIPTDIR          => { value => qq{$scriptdir},                         how => q{replace} },    # base ASGS dir, used by asgs_main.sh
                PERL5LIB           => { value => qq{$scriptdir/PERL},                    how => q{append} },     # place for distributed Perl libraries
                ADCIRC_META_DIR    => { value => qq{$asgs_home/.adcirc-meta},            how => q{replace} },    # where to track ASGS profiles (always)
                ASGS_META_DIR      => { value => qq{$asgs_home/.asgs},                   how => q{replace} },    # where to track ADCIRC installs build information (always)
                ASGS_BREW_FLAGS    => { value => qq{'$brewflags'},                       how => q{replace} },    # make brew flags available for later use
                ASGS_HOME          => { value => qq{$asgs_home},                         how => q{replace} },    # used in preference of $HOME in most cases
                ASGS_MACHINE_NAME  => { value => qq{$asgs_machine_name},                 how => q{replace} },    # machine referred to as in platforms.sh & cmplrflags.mk
                ASGS_COMPILER      => { value => qq{$asgs_compiler},                     how => q{replace} },    # compiler family designated during asgs-brew.pl build
                ASGS_INSTALL_PATH  => { value => qq{$asgs_install_path},                 how => q{replace} },    # where asgs-brew.pl installs supporting bins & libs
                ASGS_MAKEJOBS      => { value => qq{$makejobs},                          how => q{replace} },    # passed to make commands where Makefile supports
                ASGS_MESH_DEFAULTS => { value => qq{$scriptdir/config/mesh_defaults.sh}, how => q{replace} },    # list of supported meshes
                ASGS_PLATFORMS     => { value => qq{$scriptdir/platforms.sh},            how => q{replace} },    # list of supported platforms
            },
        },
        {
            key         => q{openmpi},
            name        => q{Step for OpenMPI 1.8.1 for gfortran},
            description => q{Downloads and builds OpenMPI on all platforms for ASGS. Note: gfortran is required, so any compiler option causes this step to be skipped.},
            pwd         => q{./cloud/general},
            command     => qq{bash init-openmpi.sh $asgs_install_path $asgs_compiler $makejobs},
            clean       => qq{bash init-openmpi.sh $asgs_install_path clean},

            # expose ENV *only* if --compiler=gfortran is passed as an option
            export_ENV => ( $asgs_compiler ne q{gfortran} ) ? undef : {
                PATH => { value => qq{$asgs_install_path/$asgs_compiler/bin}, how => q{prepend} },
            },

            # don't build if mpif90, etc are already available in the build environment
            skip_if             => sub { return not system(qw/which mpif90/) },
            precondition_check  => sub { 1 },
            postcondition_check => sub {
                my ( $op, $opts_ref ) = @_;
                my $bin          = qq{$asgs_install_path/$asgs_compiler/bin};
                my $ok           = 1;
                my @mpi_binaries = (qw/mpiCC mpic++ mpicc mpicxx mpiexec mpif77 mpif90 mpifort mpirun ompi-clean ompi-ps ompi-server ompi-top ompi_info opal_wrapper orte-clean orte-info orte-ps orte-server orte-top ortecc orted orterun/);
                map { $ok = -e qq[$bin/$_] && $ok } @mpi_binaries;
                return $ok;
            },
        },
        {
            key         => q{hdf5},
            name        => q{Step for HDF5 libraries and utilities},
            description => q{Downloads and builds the version of HDF5 that has been tested to work on all platforms for ASGS.},
            pwd         => q{./cloud/general},
            command     => qq{bash init-hdf5.sh $asgs_install_path $asgs_compiler $makejobs},
            clean       => qq{bash init-hdf5.sh $asgs_install_path clean},

            # augment existing %ENV (cumulative)
            export_ENV => {
                CPPFLAGS    => { value => qq{-I$asgs_install_path/include},  how => q{append}, separator => q{ }},
                LDFLAGS     => { value => qq{-L$asgs_install_path/lib},      how => q{append}, separator => q{ }},
                # the following HDF5* vars are needed for netCDF4 python module
                HDF5_DIR    => { value => qq{$asgs_install_path},            how => q{replace}},
                HDF5_LIBDIR => { value => qq{$asgs_install_path/lib},        how => q{replace}},
                HDF5_INCDIR => { value => qq{$asgs_install_path/include},    how => q{replace}},
            },
            skip_if => sub {
                my ( $op, $opts_ref ) = @_;
                my $bin = qq{$opts_ref->{'install-path'}/bin};
                my $ok  = 1;
                map { $ok = -e qq[$bin/$_] && $ok } (qw/gif2h5 h5cc h5debug h5dump h5import h5ls h5perf_serial h5repack h5stat h52gif h5copy h5diff h5fc h5jam h5mkgrp h5redeploy h5repart h5unjam/);
                return $ok;
            },    # if true and --force is not used, unilaterally skips the run step
            precondition_check  => sub { 1 },    # just a "1" indicates no checking is done
            postcondition_check => sub {
                my ( $op, $opts_ref ) = @_;
                my $bin = qq{$opts_ref->{'install-path'}/bin};
                my $ok  = 1;
                map { $ok = -e qq[$bin/$_] && $ok } (qw/gif2h5 h5cc h5debug h5dump h5import h5ls h5perf_serial h5repack h5stat h52gif h5copy h5diff h5fc h5jam h5mkgrp h5redeploy h5repart h5unjam/);
                return $ok;
            },
        },
        {
            key         => q{netcdf4},
            name        => q{Step for NetCDF4 libraries and utilities},
            description => q{Downloads and builds the versions of NetCDF and NetCFD-Fortran that have been tested to work on all platforms for ASGS.},
            pwd         => q{./cloud/general},
            command     => qq{bash init-netcdf4.sh $asgs_install_path $asgs_compiler $makejobs},
            clean       => qq{bash init-netcdf4.sh $asgs_install_path clean},

            # Note: uses environment set by setup-env step above
            # augment existing %ENV (cumulative)
            export_ENV => {
                NETCDFHOME     => { value => qq{$asgs_install_path},         how => q{replace} },
                NETCDFROOT     => { value => qq{$asgs_install_path},         how => q{replace} },    # used by SWAN's
                NETCDF4_DIR    => { value => qq{$asgs_install_path},         how => q{replace} },    # needed for netCDF4 python module
                NETCDF4_LIBDIR => { value => qq{$asgs_install_path/lib},     how => q{replace} },    # needed for netCDF4 python module
                NETCDF4_INCDIR => { value => qq{$asgs_install_path/include}, how => q{replace} },    # needed for netCDF4 python module
            },
            skip_if => sub {
                my ( $op, $opts_ref ) = @_;
                my $bin = qq{$opts_ref->{'install-path'}/bin};
                my $ok  = 1;
                map { $ok = -e qq[$bin/$_] && $ok } (qw/nc-config ncdump ncgen3 nccopy ncgen nf-config/);
                return $ok;
            },    # if true and --force is not used, unilaterally skips the run step
            precondition_check => sub {    # requires HDF5, so the precondition here is the same as the post condition of the hdf5 step above
                my ( $op, $opts_ref ) = @_;
                my $bin = qq{$opts_ref->{'install-path'}/bin};
                my $ok  = 1;
                map { $ok = -e qq[$bin/$_] && $ok } (qw/gif2h5 h5cc h5debug h5dump h5import h5ls h5perf_serial h5repack h5stat h52gif h5copy h5diff h5fc h5jam h5mkgrp h5redeploy h5repart h5unjam/);
                return $ok;
            },
            postcondition_check => sub {
                my ( $op, $opts_ref ) = @_;
                my $bin = qq{$opts_ref->{'install-path'}/bin};
                my $ok  = 1;
                map { $ok = -e qq[$bin/$_] && $ok } (qw/nc-config ncdump ncgen3 nccopy ncgen nf-config/);
                return $ok;
            },
        },
        {
            key         => q{wgrib2},
            name        => q{Step for wgrib2},
            description => q{Downloads and builds wgrib2 on all platforms for ASGS. Note: gfortran is required, so any compiler option passed is overridden.},
            pwd         => q{./},

            # -j > 1 breaks this makefile
            command             => qq{make -j 1 NETCDFPATH=$asgs_install_path NETCDF=enable NETCDF4=enable NETCDF4_COMPRESSION=enable MACHINE_NAME=$asgs_machine_name compiler=gfortran},
            clean               => q{make clean},
            skip_if             => sub { my ( $op, $opts_ref ) = @_; return -e qq{./wgrib2}; },
            precondition_check  => sub { 1 },
            postcondition_check => sub { my ( $op, $opts_ref ) = @_; return -e qq{./wgrib2}; },
        },
        {
            key                 => q{cpra-postproc},
            name                => q{Step for in output/cpra_postproc},
            description         => q{Runs the makefile and builds associated utilities in the output/cpra_postproc directory},
            pwd                 => q{./output/cpra_postproc},
            command             => qq{make -j $makejobs NETCDF_CAN_DEFLATE=enable NETCDFPATH=$asgs_install_path NETCDF=enable NETCDF4=enable NETCDF4_COMPRESSION=enable MACHINE_NAME=$asgs_machine_name compiler=$asgs_compiler},
            clean               => q{make clean},
            skip_if             => sub { my ( $op, $opts_ref ) = @_; return -e qq{./FigureGen}; },
            precondition_check  => sub { 1 },
            postcondition_check => sub { my ( $op, $opts_ref ) = @_; return -e qq{./FigureGen}; },
        },
        {
            key         => q{output},
            name        => q{Step for in output/},
            description => q{Runs the makefile and builds associated utilities in the output/ directory.},
            pwd         => q{./output},

            # -j > 1 breaks this makefile
            command             => qq{make -j 1 NETCDFPATH=$asgs_install_path NETCDF=enable NETCDF4=enable NETCDF4_COMPRESSION=enable MACHINE_NAME=$asgs_machine_name compiler=$asgs_compiler},
            clean               => q{make clean},
            skip_if             => sub { my ( $op, $opts_ref ) = @_; return -e qq{./netcdf2adcirc.x}; },
            precondition_check  => sub { 1 },
            postcondition_check => sub { my ( $op, $opts_ref ) = @_; return -e qq{./netcdf2adcirc.x}; },
        },
        {
            key                 => q{util},
            name                => q{Step for in util/},
            description         => q{Runs the makefile and builds all associated utilities in the util/ directory.},
            pwd                 => q{./util},
            command             => qq{make -j $makejobs NETCDFPATH=$asgs_install_path NETCDF=enable NETCDF4=enable NETCDF4_COMPRESSION=enable MACHINE_NAME=$asgs_machine_name compiler=$asgs_compiler},
            clean               => q{make clean},
            skip_if             => sub { my ( $op, $opts_ref ) = @_; return -e qq{./makeMax.x}; },
            precondition_check  => sub { 1 },
            postcondition_check => sub { my ( $op, $opts_ref ) = @_; return -e qq{./makeMax.x}; },
        },
        {
            key                 => q{input-mesh},
            name                => q{Step for in util/input/mesh},
            description         => q{Runs the makefile and builds all associated util/input/mesh in the input-mesh/ directory.},
            pwd                 => qq{./util/input/mesh},
            command             => qq{make -j $makejobs NETCDFPATH=$asgs_install_path NETCDF=enable NETCDF4=enable NETCDF4_COMPRESSION=enable MACHINE_NAME=$asgs_machine_name compiler=$asgs_compiler},
            clean               => q{make clean},
            skip_if             => sub { my ( $op, $opts_ref ) = @_; return -e qq{./boundaryFinder.x}; },
            precondition_check  => sub { 1 },
            postcondition_check => sub { my ( $op, $opts_ref ) = @_; return -e qq{./boundaryFinder.x}; },
        },
        {
            key         => q{input-nodalattr},
            name        => q{Step for in util/input/nodalattr},
            description => q{Runs the makefile and builds associated utilities in the util/input/nodalattr directory.},
            pwd         => q{./util/input/nodalattr},

            # -j > 1 breaks this makefile
            command             => qq{make -j 1 NETCDFPATH=$asgs_install_path NETCDF=enable NETCDF4=enable NETCDF4_COMPRESSION=enable MACHINE_NAME=$asgs_machine_name compiler=$asgs_compiler},
            clean               => q{make clean},
            skip_if             => sub { my ( $op, $opts_ref ) = @_; return -e qq{./convertna.x}; },
            precondition_check  => sub { 1 },
            postcondition_check => sub { my ( $op, $opts_ref ) = @_; return -e qq{./convertna.x}; },
        },
        {
            key         => q{perl},
            name        => q{Step for perlbrew and perl for ASGS using perlbrew},
            description => q{Installs local Perl version used for ASGS.},
            pwd         => q{./},
            command     => qq{bash ./cloud/general/init-perlbrew.sh $asgs_install_path/perl5},
            clean       => qq{bash ./cloud/general/init-perlbrew.sh $asgs_install_path/perl5 clean},

            # augment existing %ENV (cumulative) - this assumes that perlbrew is installed in $HOME and we're
            # using perl-5.32.0
            export_ENV => {
                PERLBREW_PERL    => { value => q{perl-5.32.0},                                                                   how => q{replace} },
                PATH             => { value => qq{$asgs_install_path/perl5/bin:$asgs_install_path/perl5/perls/perl-5.32.0/bin},  how => q{prepend} },
                PERLBREW_HOME    => { value => qq{$asgs_install_path/perl5/perlbrew},                                            how => q{replace} },
                PERL_CPANM_HOME  => { value => qq{$asgs_install_path/perl5/.cpanm},                                              how => q{replace} },
                PERLBREW_PATH    => { value => qq{$asgs_install_path/perl5/bin:$asgs_install_path/perl5/perls/perl-5.32.0/bin},  how => q{prepend} },
                PERLBREW_MANPATH => { value => qq{$asgs_install_path/perl5/perlbrew/perls/perl-5.32.0/man},                      how => q{prepend} },
                PERLBREW_ROOT    => { value => qq{$asgs_install_path/perl5/perlbrew},                                            how => q{replace} },
                PERL5LIB         => { value => qq{$asgs_install_path/perl5/perls/perl-5.32.0/lib/site_perl/5.28.2/},             how => q{prepend} },
            },
            skip_if => sub {
                my ( $op, $opts_ref ) = @_;
                return -e qq{$asgs_install_path/perl5/etc/bashrc};
            },
            postcondition_check => sub {
                my ( $op, $opts_ref ) = @_;
                return -e qq{$asgs_install_path/perl5/etc/bashrc};
            },
        },
        {
            key                 => q{perl-modules},
            name                => q{Step for installing, adding, and updating required Perl modules},
            description         => q{Installs Perl modules used for ASGS.},
            pwd                 => q{./},
            command             => qq{bash ./cloud/general/init-perl-modules.sh $asgs_install_path/perl5},
            clean               => sub { my $op = shift; print qq{No explicit clean step for, $op->{name}\n} },
            precondition_check  => sub { return ( -e qq{$asgs_install_path/perl5/perlbrew/perls/perl-5.32.0/bin/perl} ) ? 1 : 0 },
            postcondition_check => sub {
                local $?;
                system(qq{prove ./cloud/general/t/verify-perl-modules.t 2>&1});

                # look for zero exit code on success
                my $exit_code = ( $? >> 8 );
                return ( defined $exit_code and $exit_code == 0 ) ? 1 : 0;
            },
        },
        {
            key         => q{image-magick},
            name        => q{Step for ImageMagick},
            description => q{Installs local ImageMagick tools and Perl module Image::Magick.},
            pwd         => q{./},

            # Note, gcc is used to compile ImageMagick
            command => qq{bash ./cloud/general/init-image-magick.sh $asgs_install_path},
            clean   => qq{bash ./cloud/general/init-image-magick.sh $asgs_install_path clean},

            export_ENV => {
                MAGICK_HOME => { value => qq{$asgs_install_path}, how => q{replace} },
            },

            skip_if => sub {
                my ( $op, $opts_ref ) = @_;
                my $bins_ok = -x qq{$asgs_install_path/bin/convert};
                local $?;
                system( q[perl -MImage::Magick -e 'print qq{..ensuring Image::Magick is available.\n}' > /dev/null 2>&1] );

                # perldoc -f system  for more info on getting child process info
                # regarding the exit status
                my $exit_code = $? >> 8;

                # exit code will be 0 if successful, so return the negation of it
                return $bins_ok && ( not $exit_code );
            },

            postcondition_check => sub {
                my ( $op, $opts_ref ) = @_;
                my $bins_ok = -x qq{$asgs_install_path/bin/convert};
                local $?;
                system( q[perl -MImage::Magick -e 'print qq{..ensuring Image::Magick is available.\n}' > /dev/null 2>&1] );

                # perldoc -f system for more info on getting child process info
                # regarding the exit status
                my $exit_code = $? >> 8;

                # exit code will be 0 if successful, so return the negation of it
                return $bins_ok && ( not $exit_code );
            },
        },
        {
            # Note: updating the Python 2 version support must be done here and in the
            # ./cloud/general/init-python.sh script
            # Note: this installs Python 2, Python 3 is currently not supported (needs a new step entry)
            key         => q{python},
            name        => q{Step for installing Python 2.7.18 and required modules},
            description => q{Install Python 2.7.18 locally and install required modules},
            pwd         => q{./},
            export_ENV  => {

                # putting this in $HOME/python27/asgs/build reflects what perlbrew's default
                # behavior is doing by putting perl into $HOME/perl5/perlbrew/build/perl-$version
                PYTHONPATH => { value => $pythonpath,                               how => q{replace} },
                PATH       => { value => qq{$pythonpath/bin:$asgs_home/.local/bin}, how => q{prepend} },
            },
            command             => qq{bash ./cloud/general/init-python.sh install $pythonpath $pythonversion},
            clean               => qq{bash ./cloud/general/init-python.sh clean   $pythonpath $pythonversion},
            skip_if             => sub { 0 },
            precondition_check  => sub { 1 },
            postcondition_check => sub {
                local $?;
                system(qq{./cloud/general/t/verify-python-modules.py 2>&1});

                # look for zero exit code on success
                my $exit_code = ( $? >> 8 );
                return ( defined $exit_code and $exit_code == 0 ) ? 1 : 0;
            },
        },
        {
            key         => q{ffmpeg},
            name        => q{Step for installing ffmpeg},
            description => q{Install ffmpeg and required libraries (nasm)},
            pwd         => q{./},
            command     => qq{bash ./cloud/general/init-ffmpeg.sh $asgs_install_path gfortran 4},
            clean       => qq{bash ./cloud/general/init-ffmpeg.sh $asgs_install_path clean},
            skip_if     => sub {
                local $?;
                system(qq{$asgs_install_path/bin/ffmpeg -version > /dev/null 2>&1});

                # look for zero exit code on success
                my $exit_code = ( $? >> 8 );
                return ( defined $exit_code and $exit_code == 0 ) ? 1 : 0;
            },
            precondition_check  => sub { 1 },
            postcondition_check => sub {
                local $?;
                system(qq{$asgs_install_path/bin/ffmpeg -version > /dev/null 2>&1});

                # look for zero exit code on success
                my $exit_code = ( $? >> 8 );
                return ( defined $exit_code and $exit_code == 0 ) ? 1 : 0;
            },
        },
        {
            key         => q{gnuplot},
            name        => q{Step for installing gnuplot},
            description => q{Install gnuplot (commandline only)},
            pwd         => q{./},
            command     => qq{bash ./cloud/general/init-gnuplot-noX11.sh $asgs_install_path gfortran 4},
            clean       => qq{bash ./cloud/general/init-gnuplot-noX11.sh $asgs_install_path clean},
            skip_if     => sub {
                local $?;
                system(qq{$asgs_install_path/bin/gnuplot --version > /dev/null 2>&1});

                # look for zero exit code on success
                my $exit_code = ( $? >> 8 );
                return ( defined $exit_code and $exit_code == 0 ) ? 1 : 0;
            },
            precondition_check  => sub { 1 },
            postcondition_check => sub {
                local $?;
                system(qq{$asgs_install_path/bin/gnuplot --version > /dev/null 2>&1});

                # look for zero exit code on success
                my $exit_code = ( $? >> 8 );
                return ( defined $exit_code and $exit_code == 0 ) ? 1 : 0;
            },
        },
        {
            key         => q{units},
            name        => q{Step for installing units},
            description => q{Install GNU Units utility},
            pwd         => q{./},
            command     => qq{bash ./cloud/general/init-gnu-units.sh $asgs_install_path gfortran 4},
            clean       => qq{bash ./cloud/general/init-gnu-units.sh $asgs_install_path clean},
            skip_if     => sub {
                local $?;
                system(qq{$asgs_install_path/bin/units --version > /dev/null 2>&1});

                # look for zero exit code on success
                my $exit_code = ( $? >> 8 );
                return ( defined $exit_code and $exit_code == 0 ) ? 1 : 0;
            },
            precondition_check  => sub { 1 },
            postcondition_check => sub {
                local $?;
                system(qq{$asgs_install_path/bin/units --version > /dev/null 2>&1});

                # look for zero exit code on success
                my $exit_code = ( $? >> 8 );
                return ( defined $exit_code and $exit_code == 0 ) ? 1 : 0;
            },
        },
        {
            key         => q{nco},
            name        => q{Step for installing the NCO Toolkit},
            description => q{Install The netCDF Operators (NCO) Toolkit}, 
            pwd         => q{./},
            command     => qq{bash ./cloud/general/init-nco.sh $asgs_install_path gfortran 4},
            clean       => qq{bash ./cloud/general/init-nco.sh $asgs_install_path clean},
            skip_if     => sub {
                local $?;
                system(qq{$asgs_install_path/bin/ncwa --version > /dev/null 2>&1});

                # look for zero exit code on success
                my $exit_code = ( $? >> 8 );
                return ( defined $exit_code and $exit_code == 0 ) ? 1 : 0;
            },
            precondition_check  => sub { 1 },
            postcondition_check => sub {
                local $?;
                system(qq{$asgs_install_path/bin/ncwa --version > /dev/null 2>&1});

                # look for zero exit code on success
                my $exit_code = ( $? >> 8 );
                return ( defined $exit_code and $exit_code == 0 ) ? 1 : 0;
            },
        },
        {
            key         => q{adcirc},
            name        => q{Build ADCIRC and SWAN},
            description => q{Builds ADCIRC and SWAN if $HOME/adcirc-cg exists.},
            pwd         => qq{./},

            # expose ENV on if --build-adcirc is passed as an option
            export_ENV => {

                # always expose, always set even if not building ADCIRC
                ADCIRC_GIT_BRANCH   => { value => qq{$adcirc_git_branch}, how => q{replace} },
                ADCIRC_GIT_URL      => { value => qq{$adcirc_git_url},    how => q{replace} },
                ADCIRC_GIT_REPO     => { value => qq{$adcirc_git_repo},   how => q{replace} },
                ADCIRC_COMPILER     => { value => qq{$asgs_compiler},     how => q{replace} },
                ADCIRCBASE          => { value => ( not $opts_ref->{'build-adcirc'} ) ? undef : qq{$adcircdir-$adcirc_git_branch},      how => q{replace} },
                ADCIRCDIR           => { value => ( not $opts_ref->{'build-adcirc'} ) ? undef : qq{$adcircdir-$adcirc_git_branch/work}, how => q{replace} },
                SWANDIR             => { value => ( not $opts_ref->{'build-adcirc'} ) ? undef : qq{$adcircdir-$adcirc_git_branch/swan}, how => q{replace} },
                ADCIRC_PROFILE_NAME => { value => ( not $opts_ref->{'build-adcirc'} ) ? undef : qq{$adcirc_git_branch-$asgs_compiler},  how => q{replace} },
            },
            command => q{bash cloud/general/init-adcirc.sh},                   # Note: parameters input via environmental variables
            clean   => q{bash cloud/general/init-adcirc.sh clean},
            skip_if => sub { ( $opts_ref->{'build-adcirc'} ) ? undef : 1 },    # builds only if --build-adcirc is passed to asgs-brew.pl
        },
    ];
    return $steps;
}

1;

__END__

=head1 NAME

asgs-brew.pl

=head1 DESCRIPTION

This script is handles building all necessary libraries and utilities that
are required for a functioning local ASGS environment. It can be extended
by registering makefiles, scripts, or pure commands in the C<get_steps>
subroutine. Steps are processed in the order that they appear.

A useful interactive shell wrapper is installed upon successful completion
of all steps. See the L<ASGS INTERACTIVE SHELL> section below.

=head2 Note on script dependencies

It is very intentional that this script doesn't require anything other than
core Perl libraries that are readily available in any environment that perl
is also available.

=head1 SYNOPSIS

Options generally reflect those values that are passed on to the various
makefiles:

    ./asgs-brew.pl --machinename <MachineName> --compiler <CompilerFamily> [--install-path some/path --home /path/other/than/user/$HOME --force]

Note: C<--install-path> defaults to $HOME/opt.

There is also a "clean" mode that will invoke the C<clean> for any
step that defines it:

    ./asgs-brew.pl --clean

=head1 OPTIONS

Options translate loosely to the options that are required directly in the
commands that each step requires, and they can be added quite easily to
accomodate new pieces of information.  Below is a summary of what's been
added so far.

=head2 Required

Not including any of these options when calling C<asgs-brew.pl> will cause
termination of the script before any processing is done.

=over 3

=item C<--asgs-profile> ProfileName

Provides a globally unique name to the environment created by C<asgs-brew.pl>
so that an operator may manage more than one ASGS installation. This option
will overwrite profiles of the same name without warning. The ASGS Shell
(C<asgsh>) is installed in only one location for all profiles. It looks for
the profile named, C<default>, to load whenever it is started.

=item C<--compiler> intel|gfortran

This option allows one to define the compiler family or group, as it is
typically passed to makefiles used by ASGS. The two most common values
for this flag are going to be C<gfortran> and C<intel>.  The step is not
required to use this value. It is merely passed along so that the C<command>
string may have access to the value if it is needed.

This value is set in the environment as C<ASGS_COMPILER>.

=item C<--machinename> MachineName

This option allows one to define the C<machine> name, which is a common
value that is used in typical ASGS makefiles. It is made available for use
when defining a step. The name of the machine must be consistent with what
is in the ASGS C<platforms.sh> file and ADCIRC's C<cmplrmk.flags> file,
otherwise you will see weird issues.

This value is set in the environment as C<ASGS_MACHINE_NAME>.

=back

=head2 Additional Options

=over 3

=item C<--adcirc-git-branch> BranchTagOrSHA

This option allows the operator installing ASGS to select a specific branch,
tag, or commit hash to C<checkout> before an attempt is made to build
ADCIRC from the source. It's passed directly to a C<git checkout> command,
so valid values are determined entirely by what this C<git> command accepts.

The default value of "." (dot) is meant to indicate that there will be no
attempt to `git checkout` to the custom value (could be branch, tag, or
commit hash as stated in the paragraph above).

=item C<--adcirc-git-url> RemoteGitRepoURL

Specify the remote ADCIRC repository url; also known as a C<fork>. This is really
only useful for development activities, therefore by default it is set to
the official ADCIRC repository URL on GitHub that requires ssh key access:

L<git@github.com:adcirc>

If you wish to get access to the ADCIRC repository, please contact the maintainers.
ASGS doesn't distribute or control ADCIRC source code. If you need help
to figure out ssh key access to GitHub, please consult the online documentatino
at github.com.

=item C<--adcirc-git-repo>

Specify the name of the repo. The default is C<adcirc-cg>, which at the time
of this writing is the name of the official repository on GitHub. Chances
are very small that option needs to be changed from the default value.

=item C<--adcirc-dir> /path/to/adcirc/dir

Used in conjunction with the C<adcirc> build step. C<asgs-brew.pl> looks
here for the ADCIRC source code to build. The environmental variable,
C<ADCIRCDIR> is set using this path and will persist in the C<ASGS Shell>
where it is affects where C<asgs_main.sh> looks for the ADCIRC binaries.
This also adds C<ADCIRCBASE> and C<SWANDIR>.

=item C<--clean>

For each step, only the C<clean> (if defined) is run and then the
script quits. The purpose of this is to provide access to the the C<clean>
target that makefiles generally provide, but any command can be specificed
in the step definition.

=item C<--force>

Forcibly runs all steps, in order.

Using this option overrides any C<skip_if> conditions found in any step; it
also overrides both C<--skip-steps> and C<--run-steps>, if either has been
provided as part of the command.

=item C<--home> /path/to/alt/home

The default is set to the effective user's actual home directory, which is
the value that the environmental variable C<$HOME> is typically assigned. As
with the C<--compiler> flag, this value may or may not be used to define
some part of a step. This value also replaces the environment's HOME value
before any default paths are set (e.g., if C<--install-path> is not specified)
or any steps are executed. Anything depending on the effective user's HOME
environmental variable will see this value. This is useful when installing
ASGS from the C<$WORK> directory.

This value is set in the environment as C<ASGS_HOME>, in addition to the
traditional C<HOME> if C<--replace-home> is set.

NOTE: Unintended consequences may arise in a user's C<ASGS Shell> environment
if C<HOME> is changed.

=item C<--replace-home>

If used in conjunction with the C<--home> flag, replaces the effective user's
HOME directory variable in the environment used throughout C<asgs-brew.pl> and
provided in the ASGS Shell. This may cause unexpected results since a lot of
things outside of ASGS rely on the C<$HOME> variable and make the assumption
that it points to the effective user's actual home directory as defined in
in the system's C</etc/passwd>.

=item C<--install-path> /path/to/install/dir

Equivalent to config's C<--prefix> option, available for use as the main parent
directory under which to pass to scripts, makefiles, and other commands as
the intended home for all of the utilities you wish to rehome.

This value is set in the environment as C<ASGS_INSTALL_PATH>.

=item C<--make-jobs> Integer

Provides a way to specify the the level of concurrency one may use with
a makefile when defining the command in a step. Some makefiles are not
properly able to use this option, so it is optionally used when defining
the step command itself.

=item C<--debug>

Provides debugging output for various options.

=item C<--update-shell>

This option is provided as a way to update the C<ASGS Shell> without executing
any of the steps. 

=back

=head2 Options for C<run steps>

Flags are provided to query the current set of run steps and to run selected
steps, either by defining which steps to not run (C<--skip-steps>) or by defining
only the steps to run (C<--run-steps>). Both cases are useful almost entirely
for debugging purposes and are not generally recommends for operators installing
ASGS on well supported systems.

=over 3

=item C<--list-steps>

Prints a nice listing of each step's key (in order of execution) and the
description. It then exits, doing nothing else. It's handy when using
C<--skip-steps> since this option takes a list of keys to skip.

=item C<--skip-steps> C<step1, step2, step3, ...>

This flag is for really for debugging so that one may target a specific step,
it is not meant for the general run case of building up the ASGS environment;
asgs-brew.pl is meant to be run fully. It accepts a comma delimited list
of run step keys (no spaces) to skip. For example, if one wished to skip
the C<perl>, C<openmpi>, and C<hdf5-netcdf> steps and begin with the
C<wgrib2> step - but continue through the rest of the list, the flag would
be specificed as,

   --skip-steps=perl,openmpi,hdf5-netcdf

To get the list of keys, use the C<--list-steps> option. This option is not
compaitble with C<--run-steps>. C<--force> overrides it.

=item C<--run-steps> C<step1, step2, step3, ...>

This flag is for really for debugging so that one may target a specific step,
it is not meant for the general run case of building up the ASGS environment;
asgs-brew.pl is meant to be run fully. It accepts a comma delimited list
of run step keys (no spaces) to run. For example, if one wished to run
the C<perl>, C<openmpi>, and C<hdf5-netcdf> steps, then the flag would be
specified as,

   --run-steps=openmpi,hdf5-netcdf,perl-modules

To get the list of keys, use the C<--list-steps> option. This option is not
compatibale with C<--skip-steps>. C<--force> overrides it.

NOTE: run order is defined by how each step is defined internally, not by
the order in which they are passed to C<--run-steps>.

=back

=head1 ENVIRONMENT AND CONFIGURATION

When a Perl script is executed, it stores the user's environmental variables
(e.g., the output of the C<env> command) into a global hash, %ENV. This
script makes a local copy of that hash so that it may use and modify it as
each step requires.  Each step may define a set of environmental variables it
wishes to set and make available for subsequent steps. Once %ENV is updated,
all subsequent perl commands and spawned subshells will have access to the
modified %ENV. For example, when a Perl script runs a system command using the
backticks (e.g., `some command from the shell`), the environmental variables
and their values are governed by the %ENV global variable.

When a step builds a library that is a dependency for subsequent steps,
it is a good idea to leverage the C<export_ENV> key for each step to define
the variable and what it's new value should be.

A good example is the step that builds the NETCDF and HDF5 libraries, utlized
extensively by any utility that must read or modify ADCIRC output files,
hot start files, or external forcing data. Therefore, before the step is
executed, the following variables are among those updated in %ENV:

=over 3

=item LD_LIBRARY_PATH

=item LD_INCLUDE_PATH

=item PATH

=back

=head2 Exporting The Environment

asgs-brew.pl doesn't automatically update the user's environment as it exists
after all steps have been run successfully. Since there is the ability to
export environmental variables in each step (available for the current and
subsequent steps), it might be desired to be able to recreate this post-run.

For ease of use, a wrapper around the native bash shell is installed called
C<asgsh>. Instructions on starting this shell environment are output at the
end of a successful installation. Included in this environment are a set of
ASGS specific commands and the full environment as it existed at the end.

Documentation of the ASGS Shell is contained as a help section in the shell
itself. The C<--update-shell> option may be used with C<asgs-brew.pl> to
update to the latest version of this shell environment without have to run
each step.

There is also additional information in the C<ASGS INTERACTIVE SHELL> section
below.

=head1 ADDING AND MANAGING STEPS

When adding a new step, it is important to consider where in the order of
steps it should appear. If it's a library used by many utilities (e.g.,
NetCDF or HDF5), additional care must be made when specifying the step -
in particular the environmental variables that is standard for compilers
utilize, such as C<LD_INCLUDE_PATH> or C<LD_LIBRARY_PATH>.

NOTE: The best way to learn about the structure of a step is to inspect the
source code of C<asgs-brew.pl>. What follows is a reference, but doesn't give
as clear of a picture as viewing the actual implementation details.

The defined C<keys> to define when adding a step are as follow,

=over 3

=item C<key>

Unique key that is meant to unambiguously refer to the step in options
that may accept a list of steps. For example, it's required for using the
C<--list-steps> flag.

=item C<description>

Provides a fair, short summary of the step. Required for the C<--list-steps>
flag to act appropriately.

=item C<name>

Short name for the step, doesn't have to be unique across steps and runs,
but it's good to make sure that the name is short and informative.

=item C<pwd>

The directory specified is the one from where the step's C<command> should
be run.

=item C<command>

This is the primary command is run in the current step unless the C<--clean>
flag is specified. Options are passed from the commandline of asgs-brew.pl to
the C<$opts_ref> hash reference by using the C<Getops::Long> options definition
in the C<run> subroutine.  Options can be added easily to the arguments list
of asgs-brew.pl, but the general rule of thumb should be that the options be
kept to a minimum. Most of the complexity associated with a step should be
hidden within the step's makefile, script, or program supporting the command.

A command can either be a string, which is evaluated using the C<system> command;
or it can be an anonymous Perl subroutine. In this case, when the reference is
called it will be pased a reference of the step's fully defined hash and
all options and tracked internal information that is tracked in the code with
the C<$opts_ref> varable (inspect asgs-brew.pl's code to see this).

=item C<export_ENV>

Environmental variables affect a great number of things in this space, so it
is important to be able to manage them as each step completes. Each step may
define any number of environmental variables and how they should be updated.

Below is an example used for the C<hdf5-netcdf> step. This example demonstrates
which variables to update, with what value, and how.

    export_ENV => {
	LD_LIBRARY_PATH => { value => qq{$asgs_install_path/lib},     how => q{prepend} },
	LD_INCLUDE_PATH => { value => qq{$asgs_install_path/include}, how => q{prepend} },
	NETCDFHOME      => { value => qq{$asgs_install_path},         how => q{replace} },
    },

Options for C<how> include: C<prepend> (default if not defined), C<append>,
and C<replace>.

=item C<clean>

Defines the command used to C<clean> a directory tree. As with C<command>, this
can be either a string or a subroutine reference. See C<command> information
above for more details.

=item C<skip_if>

Defines the condition on which the run step can be skipped. This check can
be bypassed if the C<--force> flag is passed. It is similar in nature to the
C<postcondition_check> or C<precondition_check>, but has been separated out
for the purpose of selectively ignoring a run step if desired. This check
happens BEFORE C<precondition_check>.

=item C<precondition_check>

If this method is private, it is run before C<command>. If it fails, then
appropriate action should be taken to fix that.

=item C<postcondition_check>

If this method is private, it is run after C<command>. If it fails, then
appropriate.

=back

=head2 A Note about Interdependency Among Steps

This script has no means of enforcing dependency among scripts, but this
can be added if needed in the future. The steps are executed serially, but
there is no limit to the concurrency that each individiual step can have -
for example, C<make> is very good at concurrently running independent portions
of the makefile if it is set up correctly (and by using the C<-j> option).

It is assumed that each step MUST complete successfully, and this is why there
is a C<postcondition_check> method that can be customized to ensure that
the expected state after the step is complete has been satisfied. Failure
of this method at any step will result in the script stopping. Similarly,
each step is able to also define a C<precondition_check> that also must be
evaluate positively if the step itself is to be attempted.

=head1 ASGS INTERACTIVE SHELL

A successful completion of the running of this script installs an interactive
shell environment that makes available all environmental updates made by the
steps. The shell also provides some convenient ASGS specific commands that
make running and operating ASGS easier. Commands will be added as needed. To
read more about the shell, please read the C<README.asgsh>.

=head1 LICENSE AND COPYRIGHT

This file is part of the ADCIRC Surge Guidance System (ASGS).  The ASGS is
free software: you can redistribute it and/or modify it under the terms of
the GNU General Public License as published by the Free Software Foundation,
either version 3 of the License, or (at your option) any later version.

ASGS is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
the ASGS. If not, see <http://www.gnu.org/licenses/>.
