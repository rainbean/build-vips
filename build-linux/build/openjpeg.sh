#!/usr/bin/env bash

echo "Build openjpeg"
OPENJPEG2_VERSION=2.5.2
if [[ -f "/data/cache/openjpeg.tar.gz" ]]; then cp /data/cache/openjpeg.tar.gz .; else wget -q https://github.com/uclouvain/openjpeg/archive/refs/tags/v${OPENJPEG2_VERSION}.tar.gz -O openjpeg.tar.gz; fi
tar xf openjpeg.tar.gz
cd openjpeg-${OPENJPEG2_VERSION}
cmake -Bbuild -H. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local
make -C build -j $(nproc)
make -C build install/strip