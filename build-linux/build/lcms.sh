#!/usr/bin/env bash

echo "Build lcms"
LCMS_VERSION=2.16
if [[ -f "/data/cache/lcms2.tar.gz" ]]; then cp /data/cache/lcms2.tar.gz .; else wget -q https://github.com/mm2/Little-CMS/releases/download/lcms${LCMS_VERSION}/lcms2-${LCMS_VERSION}.tar.gz -O lcms2.tar.gz; fi
tar xf lcms2.tar.gz
cd lcms2-${LCMS_VERSION}
meson setup build --buildtype release
meson compile -C build
meson install -C build