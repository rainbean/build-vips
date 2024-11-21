#!/usr/bin/env bash

echo "Build openslide"
OPENSLIDE_TAG="2024-11-21"
wget -q https://github.com/rainbean/openslide/archive/refs/tags/${OPENSLIDE_TAG}.tar.gz -O openslide.tar.gz
tar xf openslide.tar.gz
cd openslide-${OPENSLIDE_TAG}
meson setup build \
    --buildtype release \
    -Dtest=disabled \
    -Ddoc=disabled
meson compile -C build
meson install -C build
