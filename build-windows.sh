#!/usr/bin/env bash

# Apply patches over the submodule, stage license files into the build
# directory so the container can reach them at /data/, then delegate to
# the submodule build script.  Everything is restored on exit.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build-win64-mxe/build"

cleanup() {
    patch -p1 -R --quiet -d "$SCRIPT_DIR" < "$SCRIPT_DIR/patch/vips-all.mk.patch" 2>/dev/null || true
    patch -p1 -R --quiet -d "$SCRIPT_DIR" < "$SCRIPT_DIR/patch/vips-web.mk.patch" 2>/dev/null || true
    rm -f "$BUILD_DIR/THIRD-PARTY-NOTICES"
}
trap cleanup EXIT

# Apply local patches over the submodule files
patch -p1 -d "$SCRIPT_DIR" < "$SCRIPT_DIR/patch/vips-all.mk.patch"
patch -p1 -d "$SCRIPT_DIR" < "$SCRIPT_DIR/patch/vips-web.mk.patch"
cp "$SCRIPT_DIR/patch"/*.mk "$BUILD_DIR/"

# Stage license file so the container can reach it at /data/
cp "$SCRIPT_DIR/THIRD-PARTY-NOTICES" "$BUILD_DIR/"

cd "$SCRIPT_DIR/build-win64-mxe"
./build.sh all "$@"
