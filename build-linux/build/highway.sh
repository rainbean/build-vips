#!/usr/bin/env bash

echo "Build highway"
HIGHWAY_VERSION=1.1.0
wget -q https://github.com/google/highway/archive/refs/tags/${HIGHWAY_VERSION}.tar.gz -O highway.tar.gz
tar xf highway.tar.gz
cd highway-${HIGHWAY_VERSION}
cmake -Bbuild -H. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DBUILD_TESTING=OFF \
    -DHWY_ENABLE_CONTRIB=OFF \
    -DHWY_ENABLE_EXAMPLES=OFF
make -C build -j 4
make -C build install/strip