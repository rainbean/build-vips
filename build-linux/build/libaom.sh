#!/usr/bin/env bash

echo "Build AOM"
AOM_VERSION=3.8.2
wget -q https://storage.googleapis.com/aom-releases/libaom-${AOM_VERSION}.tar.gz -O libaom.tar.gz
tar xf libaom.tar.gz
cd libaom-${AOM_VERSION}
cmake -Bbuild -H. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DENABLE_NASM=ON \
    -DENABLE_DOCS=OFF \
    -DENABLE_TESTS=OFF \
    -DENABLE_TESTDATA=OFF \
    -DENABLE_TOOLS=OFF \
    -DENABLE_EXAMPLES=OFF \
    -DCONFIG_AV1_HIGHBITDEPTH=0 \
    -DCONFIG_WEBM_IO=0
make -C build -j 4
make -C build install
