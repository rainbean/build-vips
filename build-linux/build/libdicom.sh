#!/usr/bin/env bash

echo "Build libdicom"
DICOM_VERSION=1.0.5
wget -q https://github.com/ImagingDataCommons/libdicom/releases/download/v${DICOM_VERSION}/libdicom-${DICOM_VERSION}.tar.xz -O libdicom.tar.xz
tar xf libdicom.tar.xz
cd libdicom-${DICOM_VERSION}
meson setup build --buildtype release
meson compile -C build
meson install -C build