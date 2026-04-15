#!/usr/bin/env bash

echo "Build mozjpeg"
MOZJPEG_VERSION=4.1.5
if [[ -f "/data/cache/mozjpeg.tar.gz" ]]; then cp /data/cache/mozjpeg.tar.gz .; else wget -q https://github.com/mozilla/mozjpeg/archive/refs/tags/v${MOZJPEG_VERSION}.tar.gz -O mozjpeg.tar.gz; fi
tar xf mozjpeg.tar.gz
cd mozjpeg-${MOZJPEG_VERSION}
cmake -Bbuild -H. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DWITH_TURBOJPEG=OFF
make -C build -j $(nproc)
make -C build install/strip