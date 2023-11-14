#!/usr/bin/env bash

echo "Build openslide"
OPENSLIDE_TAG=4.0.0
OPENSLIDE_VERSION=4.0.0
wget -q https://github.com/openslide/openslide/releases/download/v${OPENSLIDE_TAG}/openslide-${OPENSLIDE_VERSION}.tar.xz -O openslide.tar.xz
tar xf openslide.tar.xz
cd openslide-${OPENSLIDE_VERSION}
meson setup build --buildtype release
meson compile -C build
meson install -C build