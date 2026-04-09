#!/usr/bin/env bash

echo "Build libtiff"
TIFF_VERSION=4.7.0
wget -q https://download.osgeo.org/libtiff/tiff-${TIFF_VERSION}.tar.gz -O libtiff.tar.gz
tar xf libtiff.tar.gz
cd tiff-${TIFF_VERSION}
cmake -Bbuild -H. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -Djbig=OFF \
    -Ddeflate=OFF
make -C build -j $(nproc)
make -C build install/strip
