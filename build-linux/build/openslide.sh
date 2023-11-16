#!/usr/bin/env bash

echo "Build openslide"
OPENSLIDE_TAG="2023-11-15"
https://github.com/rainbean/openslide/archive/refs/tags/2023-11-15.tar.gz
wget -q https://github.com/rainbean/openslide/archive/refs/tags/${OPENSLIDE_TAG}.tar.gz -O openslide.tar.gz
tar xf openslide.tar.gz
cd openslide-${OPENSLIDE_TAG}
meson setup build --buildtype release
meson compile -C build
meson install -C build
