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
./build-windows.sh [OPTIONS] [ARCH] [TYPE]
```

Builds the `all` dependency set (full feature set). The script patches the
submodule, runs the build, and restores the submodule on exit.

Key options:

| Option | Description |
|---|---|
| `--with-hevc` | Add HEVC support |
| `--with-jpegli` | Use jpegli instead of mozjpeg |
| `--without-llvm` | Use GCC instead of LLVM/Clang |
| `--without-zlib-ng` | Use vanilla zlib instead of zlib-ng |
| `--nightly` / `-r <REF>` / `-c <COMMIT>` | Build from a specific version |

`ARCH` defaults to `x86_64`. Supported: `x86_64`, `i686`, `aarch64`, `armv7`.  
`TYPE` defaults to `shared`. Supported: `shared`, `static`.

## Patches

`patch/` contains unified diffs applied over the `build-win64-mxe` submodule
at build time by `build-windows.sh`. To update a patch after changing the
target behaviour, regenerate it against the submodule original:

```shell
diff -u \
  --label a/build-win64-mxe/build/vips-all.mk \
  --label b/build-win64-mxe/build/vips-all.mk \
  build-win64-mxe/build/vips-all.mk \
  <modified-file> > patch/vips-all.mk.patch
```

## SBOM

- install [CycloneDX Generator](https://cyclonedx.github.io/cdxgen/): `npm install -g @cyclonedx/cdxgen`
- generate SBOM: `cdxgen -o sbom.json`
