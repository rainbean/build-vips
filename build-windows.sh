#!/usr/bin/env bash

# Apply patches over the submodule, then delegate to the submodule build
# script.  Everything is restored on exit.
#
# Submodule is pinned to build-win64-mxe v8.15.5 to match the libvips
# version pin (8.16.0+ has a ~2x WSI conversion regression).
# See: https://github.com/rainbean/build-vips/issues/7
#
# Usage: ./build-windows.sh [DEPS] [ARCH] [TYPE]
#   DEPS: web (default from submodule) or all  — we default to "all"
#   ARCH: x86_64 (default), i686, aarch64
#   TYPE: shared (default), static

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cleanup() {
    patch -p1 -R --quiet -d "$SCRIPT_DIR" < "$SCRIPT_DIR/patch/openslide.mk.patch" 2>/dev/null || true
}
trap cleanup EXIT

# Apply local patches over the submodule files
patch -p1 -d "$SCRIPT_DIR" < "$SCRIPT_DIR/patch/openslide.mk.patch"

cd "$SCRIPT_DIR/build-win64-mxe"
./build.sh "${@:-all}"
