#!/usr/bin/env bash

echo "Build libvips"
VIPS_VERSION=8.15.2
wget -q https://github.com/libvips/libvips/releases/download/v${VIPS_VERSION}/vips-${VIPS_VERSION}.tar.xz -O vips.tar.xz
tar xf vips.tar.xz
cd vips-${VIPS_VERSION}
meson setup build \
    --buildtype release \
    -Ddeprecated=false \
    -Dexamples=false \
    -Dintrospection=disabled \
    -Dfontconfig=disabled \
    -Dpangocairo=disabled \
    -Dpdfium=disabled \
    -Dquantizr=disabled \
    -Dmodules=disabled \
    -Dopenjpeg=enabled \
    -Djpeg-xl=enabled
meson compile -C build
meson install -C build