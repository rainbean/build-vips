#!/usr/bin/env bash

echo "Build libwebp"
LIBWEBP_VERSION=1.6.0
if [[ -f "/data/cache/libwebp-${LIBWEBP_VERSION}.tar.gz" ]]; then cp /data/cache/libwebp-${LIBWEBP_VERSION}.tar.gz libwebp.tar.gz; else wget -q https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-${LIBWEBP_VERSION}.tar.gz -O libwebp.tar.gz; fi
tar xf libwebp.tar.gz
cd libwebp-${LIBWEBP_VERSION}
# Shared libs into /usr/local/lib so pkg-config prefers this over the apt libwebp 1.2.2.
# Example tools are disabled (no libpng/jpeg/tiff link needed); the libwebp/
# libwebpmux/libwebpdemux/libsharpyuv libraries libvips consumes are still built.
cmake -G Ninja -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DWEBP_BUILD_CWEBP=OFF \
    -DWEBP_BUILD_DWEBP=OFF \
    -DWEBP_BUILD_GIF2WEBP=OFF \
    -DWEBP_BUILD_IMG2WEBP=OFF \
    -DWEBP_BUILD_VWEBP=OFF \
    -DWEBP_BUILD_WEBPINFO=OFF \
    -DWEBP_BUILD_ANIM_UTILS=OFF \
    -DWEBP_BUILD_EXTRAS=OFF
cmake --build build --target install
