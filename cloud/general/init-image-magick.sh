#!/bin/bash

OPT=${1-$ASGS_INSTALL_PATH}
JOBS=${2-$ASGS_MAKEJOBS}
TMP=/tmp/$USER-asgs

IMAGEMAGICK_VERSION="7.0.11-10"

if [ "$2" == "clean" ]; then 
  echo Cleaning Image Magick libraries and utilities
  cd $OPT/bin
  rm -rfv animate composite convert identify magick MagickCore-config MagickWand-config
  rm -rfv montage compare conjure display import Magick++-config magick-script mogrify stream
  cd $OPT/lib
  rm -rfv libMag*
  cd $OPT/lib/pkgconfig
  rm -rfv ImageMagick-7.Q16HDRI.pc Magick++-7.Q16HDRI.pc MagickCore.pc MagickWand-7.Q16HDRI.pc
  rm -rfv ImageMagick.pc MagickCore-7.Q16HDRI.pc Magick++.pc MagickWand.pc
  cd $OPT/include
  rm -rfv "ImageMagick-7"
  cd $OPT/etc
  rm -rfv "ImageMagick-7"
  cd $OPT/share
  rm -rfv "share/doc/ImageMagick-7" 
  cd $OPT/share/man/man1
  rm -rfv animate.1 compare.1 composite.1 conjure.1 convert.1 display.1 identify.1 ImageMagick.1
  rm -rfv import.1 magick.1 Magick++-config.1 MagickCore-config.1 magick-script.1 MagickWand-config.1 mogrify.1
  rm -rfv montage.1 stream.1
  exit
fi

mkdir -p $TMP 2> /dev/null
chmod 700 $TMP

if [ ! -d $OPT ]; then
  mkdir -p $OPT
else
  if [ -e $OPT/bin/convert ]; then
    echo Looks like Image Magick has been built
    exit 0  
  fi
fi
cd $TMP

if [ ! -e ${IMAGEMAGICK_VERSION}.tar.gz ]; then 
  wget https://github.com/ImageMagick/ImageMagick/archive/${IMAGEMAGICK_VERSION}.tar.gz
else
  echo Found $TMP/${IMAGEMAGICK_VERSION}.tar.gz
  rm -rf ./ImageMagic-${IMAGEMAGICK_VERSION} >/dev/null 2>&1
fi
tar -xvf $IMAGEMAGICK_VERSION.tar.gz
cd ImageMagick-$IMAGEMAGICK_VERSION 

export CC=gcc
export MAGICK_HOME=$ASGS_INSTALL_PATH

./configure --prefix=$ASGS_INSTALL_PATH --with-gcc-arch=native --with-perl=$(which perl) \
    --without-magick-plus-plus --disable-openmp

make
make install
