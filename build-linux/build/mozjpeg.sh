#!/usr/bin/env bash

echo "Build mozjpeg"
MOZJPEG_VERSION=4.1.5
wget -q https://github.com/mozilla/mozjpeg/archive/refs/tags/v${MOZJPEG_VERSION}.tar.gz -O mozjpeg.tar.gz
tar xf mozjpeg.tar.gz
cd mozjpeg-${MOZJPEG_VERSION}
cmake -Bbuild -H. \
    -DCMAKE_BUILD_TYPE=Release \
    -DWITH_TURBOJPEG=OFF \
    -DCMAKE_INSTALL_PREFIX=/usr/local
make -C build -j 4
make -C build install/strip