#!/usr/bin/env bash

echo "Build libspng"
SPNG_VERSION=0.7.4
if [[ -f "/data/cache/libspng.tar.gz" ]]; then cp /data/cache/libspng.tar.gz .; else wget -q https://github.com/randy408/libspng/archive/refs/tags/v${SPNG_VERSION}.tar.gz -O libspng.tar.gz; fi
tar xf libspng.tar.gz
cd libspng-${SPNG_VERSION}
meson setup build \
    --buildtype=release \
    -Dbuild_examples=false
meson compile -C build
meson install -C build