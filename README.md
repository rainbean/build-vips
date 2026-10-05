# build-vips

Build vips and its dependencies

## Getting Started

- update submodules: `git submodule update --init --recursive`

### Linux

```shell
cd build-linux
./build.sh
```

Output: `build-linux/build/vips-linux-{arch}-{date}.tar.gz`

### Windows

```shell
./build-windows.sh
```

Builds libvips for Windows x86_64 (shared, all deps). Applies patches over
the submodule, runs the build, and restores the submodule on exit.

## Patches

`patch/` contains unified diffs applied over the `build-win64-mxe` submodule
at build time by `build-windows.sh`. To update a patch after changing the
target behaviour, regenerate it against the submodule original:

```shell
git -C build-win64-mxe diff \
  --src-prefix=a/build-win64-mxe/ \
  --dst-prefix=b/build-win64-mxe/ \
  build/<file>.mk > patch/<file>.mk.patch
```

## SBOM

SBOMs for each released build are generated in the decart repo, which ships these packages:
the catalogs are in `sbom/bundles/vips/<build>/` and the procedure is in decart's `docs/sbom.md`.
For a new build, keep dependency versions pinned in the build scripts and `THIRD-PARTY-NOTICES`
up to date. Those are what the catalog is written from. Don't run `cdxgen` over the build tree:
it lists the build toolchain, not what ships.
