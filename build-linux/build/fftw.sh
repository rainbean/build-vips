#!/usr/bin/env bash

echo "Build FFTW"
FFTW_VERSION=3.3.10
wget -q https://fftw.org/fftw-${FFTW_VERSION}.tar.gz -O fftw.tar.gz
tar xf fftw.tar.gz
cd fftw-${FFTW_VERSION}
cmake -Bbuild -H. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local
make -C build -j 4
make -C build install/strip
