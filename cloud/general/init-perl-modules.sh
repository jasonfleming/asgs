#!/bin/bash

# unconditionally attempts to install the Perl modules that are required

PERLBREW_ROOT=${1-$HOME/perl5/perlbrew}
source $PERLBREW_ROOT/etc/bashrc

if [ "${2}" = "clean" ]; then
  # uninstall tempermental modules first
  for module in $(cat ./PERL-MODULES.notest); do
    echo Y | cpanm --uninstall $module
  done

  # uninstall the rest
  for module in $(cat ./PERL-MODULES); do
    echo Y | cpanm --uninstall $module
  done
  exit
fi  

if [ ! -e $PERLBREW_ROOT/bin/cpanm ]; then
  echo installing cpanm...
  perlbrew install-cpanm
fi

echo Installing Perl modules required for ASGS

MIRROR="https://www.cpan.org/"

# install tempermental modules first
for module in $(cat ./PERL-MODULES.notest); do
  cpanm --from $MIRROR --verbose --notest --with-suggests $module
done

# run tests on these installations
for module in $(cat ./PERL-MODULES); do
  cpanm --from $MIRROR --verbose --with-suggests $module || exit 1 # forces script to exit with error, asgs-brew.pl will catch and report this
done

# copy over ./PERL/perltidyrc to $HOME/.perltidyrc
cp ./PERL/perltidyrc $HOME/.perltidyrc
