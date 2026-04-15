#!/usr/bin/env bash

echo "Install latest compatible cmake"
CMAKE_VERSION=3.28.6
ARCH=$(uname -m)
TARBALL="cmake-${CMAKE_VERSION}-linux-${ARCH}.tar.gz"
# Use pre-downloaded tarball from the mounted build dir (/data) if present
if [[ -f "/data/${TARBALL}" ]]; then
  echo "Using cached ${TARBALL}"
  cp "/data/${TARBALL}" .
else
  wget -q https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/${TARBALL}
fi
tar xf "${TARBALL}" --strip-components=1 -C /usr