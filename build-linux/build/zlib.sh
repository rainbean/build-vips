#!/usr/bin/env bash

echo "Build zlib-ng"
ZLIBNG_VERSION=2.1.4
wget -q https://github.com/zlib-ng/zlib-ng/archive/refs/tags/${ZLIBNG_VERSION}.tar.gz -O zlib-ng.tar.gz
tar xf zlib-ng.tar.gz
cd zlib-ng-${ZLIBNG_VERSION}
cmake -Bbuild -H. \
    -DZLIB_COMPAT=ON \
    -DZLIB_ENABLE_TESTS=OFF
make -C build -j 4
make -C build install/strip