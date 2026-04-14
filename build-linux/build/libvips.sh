#!/usr/bin/env bash

echo "Build libvips"
VIPS_VERSION=8.18.2
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
    -Djpeg=enabled \
    -Dwebp=enabled \
    -Dtiff=enabled \
    -Dheif=disabled \
    -Djpeg-xl=disabled \
    -Dmagick=disabled \
    -Dopenexr=disabled \
    -Dfftw=disabled \
    -Dmatio=disabled \
    -Dcfitsio=disabled \
    -Dpoppler=disabled \
    -Darchive=enabled
meson compile -C build
meson install -C build