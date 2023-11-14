#!/usr/bin/env bash

# exit on error
set -e

. variables.sh

# shall be /data in container
work_dir=$(pwd)

# build each library
deps=('cmake' 'openjpeg' 'lcms' 'libspng' 'mozjpeg' 'highway' 'libjxl' 'libdicom' 'openslide' 'libvips')
for lib in "${deps[@]}"
do
    cd /var/tmp
    . $work_dir/$lib.sh
done

# pack package
cd $work_dir
. $work_dir/package.sh

