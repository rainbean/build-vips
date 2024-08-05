#!/usr/bin/env bash

echo "Build Imath"
IMATH_VERSION=3.1.9
wget -q https://github.com/AcademySoftwareFoundation/Imath/archive/refs/tags/v${IMATH_VERSION}.tar.gz -O imath.tar.gz
tar xf imath.tar.gz
cd Imath-${IMATH_VERSION}
cmake -Bbuild -H. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DBUILD_TESTING=OFF \
    -DIMATH_INSTALL_PKG_CONFIG=ON \
    -DBUILD_SHARED_LIBS=OFF
make -C build -j 4
make -C build install