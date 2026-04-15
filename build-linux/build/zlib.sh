#!/usr/bin/env bash

echo "Build zlib-ng"
ZLIBNG_VERSION=2.1.4
if [[ -f "/data/cache/zlib-ng.tar.gz" ]]; then cp /data/cache/zlib-ng.tar.gz .; else wget -q https://github.com/zlib-ng/zlib-ng/archive/refs/tags/${ZLIBNG_VERSION}.tar.gz -O zlib-ng.tar.gz; fi
tar xf zlib-ng.tar.gz
cd zlib-ng-${ZLIBNG_VERSION}
cmake -Bbuild -H. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DZLIB_COMPAT=ON \
    -DZLIB_ENABLE_TESTS=OFF
make -C build -j $(nproc)
make -C build install/strip
