#!/usr/bin/env bash

echo "Install latest compatible cmake"
CMAKE_VERSION=3.28.6
ARCH=$(uname -m)
wget -q https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-${ARCH}.tar.gz
tar xf cmake-${CMAKE_VERSION}-linux-${ARCH}.tar.gz --strip-components=1 -C /usr