#!/usr/bin/env bash

echo "Build openslide"
OPENSLIDE_TAG="2023-11-15"
wget -q https://github.com/rainbean/openslide/releases/download/${OPENSLIDE_TAG}/openslide.tar.gz -O openslide.tar.gz
tar xf openslide.tar.gz
cd openslide
meson setup build --buildtype release
meson compile -C build
meson install -C build