# build-vips

Build vips and its dependencies

## Getting Start

- update submodules - `git submodule update --init --recursive`
- build Linux:

```shell
cd build-linux
./build.sh
```

- build Windows:

```shell
cp patch/*.mk build-win64-mxe/build
cd build-win64-mxe
./build.sh all
```

## SBOM

- install (CycloneDX Generator)[https://cyclonedx.github.io/cdxgen/] - `npm install -g @cyclonedx/cdxgen`
- generate SBOM - `cdxgen -o sbom.json`

