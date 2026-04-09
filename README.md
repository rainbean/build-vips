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
diff -u \
  --label a/build-win64-mxe/build/<file>.mk \
  --label b/build-win64-mxe/build/<file>.mk \
  <(cd build-win64-mxe && git show HEAD:build/<file>.mk) \
  build-win64-mxe/build/<file>.mk \
  > patch/<file>.mk.patch
```

## SBOM

- install [CycloneDX Generator](https://cyclonedx.github.io/cdxgen/): `npm install -g @cyclonedx/cdxgen`
- generate SBOM: `cdxgen -o sbom.json`
