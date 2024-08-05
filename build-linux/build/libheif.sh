#!/usr/bin/env bash

echo "Build libheif"
HEIF_VERSION=1.17.6
wget -q https://github.com/strukturag/libheif/releases/download/v${HEIF_VERSION}/libheif-${HEIF_VERSION}.tar.gz -O libheif.tar.gz
tar xf libheif.tar.gz
cd libheif-${HEIF_VERSION}
cmake -Bbuild -H. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DENABLE_PLUGIN_LOADING=0 \
    -DWITH_EXAMPLES=0
make -C build -j 4
make -C build install/strip
