#!/usr/bin/env bash

# Apply patches and stage license files into the build directory so they are
# accessible inside the container at /data, then delegate to the submodule
# build script.  The copied files are removed on exit regardless of outcome.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build-win64-mxe/build"

cleanup() {
    rm -f "$BUILD_DIR/THIRD-PARTY-NOTICES"
}
trap cleanup EXIT

# Apply local patches over the submodule
cp "$SCRIPT_DIR/patch"/*.mk "$BUILD_DIR/"

# Stage license files so the container can reach them at /data/
cp "$SCRIPT_DIR/THIRD-PARTY-NOTICES" "$BUILD_DIR/"

cd "$SCRIPT_DIR/build-win64-mxe"
exec ./build.sh "$@"
