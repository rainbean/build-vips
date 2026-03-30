#!/usr/bin/env bash

# Auto-detect host architecture and select the matching Docker platform
case $(uname -m) in
    x86_64)        platform="linux/amd64" ;;
    arm64|aarch64) platform="linux/arm64" ;;
    *)             platform="linux/$(uname -m)" ;;
esac

# Build a machine image with all the required build tools pre-installed
docker build --platform $platform -t libvips-build-linux container

# Run build scripts inside a container with the:
# - correct platform for this host
# - build dir mounted at /data
docker run --rm -t \
  --platform $platform \
  -v $PWD/build:/data \
  libvips-build-linux
