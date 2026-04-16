#!/usr/bin/env bash

# Apply patches over the submodule, stage license files into the build
# directory so the container can reach them at /data/, then delegate to
# the submodule build script.  Everything is restored on exit.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build-win64-mxe/build"

DLLDIR_PATCH="$BUILD_DIR/plugins/all-deps/patches/vips-8-dlldir-as-libdir.patch"

cleanup() {
    patch -p1 -R --quiet -d "$SCRIPT_DIR" < "$SCRIPT_DIR/patch/vips.mk.patch" 2>/dev/null || true
    patch -p1 -R --quiet -d "$SCRIPT_DIR" < "$SCRIPT_DIR/patch/vips-all.mk.patch" 2>/dev/null || true
    patch -p1 -R --quiet -d "$SCRIPT_DIR" < "$SCRIPT_DIR/patch/vips-all-overrides.mk.patch" 2>/dev/null || true
    patch -p1 -R --quiet -d "$SCRIPT_DIR" < "$SCRIPT_DIR/patch/openslide.mk.patch" 2>/dev/null || true
    git -C "$SCRIPT_DIR/build-win64-mxe" checkout -- build/plugins/all-deps/patches/vips-8-dlldir-as-libdir.patch 2>/dev/null || true
    rm -f "$BUILD_DIR/THIRD-PARTY-NOTICES"
}
trap cleanup EXIT

# Apply local patches over the submodule files
patch -p1 -d "$SCRIPT_DIR" < "$SCRIPT_DIR/patch/vips.mk.patch"
patch -p1 -d "$SCRIPT_DIR" < "$SCRIPT_DIR/patch/vips-all.mk.patch"
patch -p1 -d "$SCRIPT_DIR" < "$SCRIPT_DIR/patch/vips-all-overrides.mk.patch"
patch -p1 -d "$SCRIPT_DIR" < "$SCRIPT_DIR/patch/openslide.mk.patch"

# Replace dlldir patch with a version compatible with libvips 8.15.5
# (the upstream patch uses context that doesn't exist before 8.16.0)
cp "$SCRIPT_DIR/patch/vips-8-dlldir-as-libdir.patch" "$DLLDIR_PATCH"

# Stage license file so the container can reach it at /data/
cp "$SCRIPT_DIR/THIRD-PARTY-NOTICES" "$BUILD_DIR/"

cd "$SCRIPT_DIR/build-win64-mxe"
./build.sh "${@:-vips-all}"
