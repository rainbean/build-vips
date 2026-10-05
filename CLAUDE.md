# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Purpose

This repository builds cross-platform **libvips** binaries and their full dependency trees
for Linux and Windows. It contains no application code — it is a build-orchestration system
that produces distributable, self-contained tarballs with bundled licenses.

## Building

### Linux (Docker-based)

```bash
cd build-linux
./build.sh
```

`build.sh` detects host arch via `uname -m` (x86_64→amd64, arm64/aarch64→arm64), builds the
`libvips-build-linux` image from `container/Dockerfile` (base `ubuntu:jammy`, Clang + Meson +
Ninja), then runs the container with `build/` mounted at `/data` and the repo root at
`/repo:ro`. Output: `vips-linux-{x64|arm64}-$(date +%F).tar.gz` in `build-linux/build/`.

Build sequence (`build-linux/build/build.sh`):
cmake → zlib → lcms → openjpeg → libspng → mozjpeg → libtiff → libdicom → openslide →
libvips → package

FFTW is **not** built on Linux (`-Dfftw=disabled` in `libvips.sh`). Source tarballs are
cached under `build-linux/build/cache/` to avoid re-downloading across runs.

### Windows (MXE cross-compilation)

```bash
./build-windows.sh
```

Run from the repo root — do **not** invoke the submodule's `build.sh` directly. The wrapper:
1. copies `THIRD-PARTY-NOTICES` into the submodule build dir,
2. applies each `patch/*.mk.patch` over the `build-win64-mxe` submodule with `patch -p1`,
3. delegates to `build-win64-mxe/build.sh`,
4. **reverses the patches on exit** (trap) so the submodule is never left modified.

The underlying engine is `build-win64-mxe/build.sh [OPTIONS] [DEPS] [ARCH] [TYPE]`:
- `DEPS`: `web` (default, lighter) or `all` (DICOM, OpenEXR, FITS, FFTW, etc.)
- `ARCH`: `x86_64` (default), `i686`, `aarch64`, `armv7`
- `TYPE`: `shared` (default) or `static` (static disallowed with `all` due to GPL)
- Flags: `--with-hevc`, `--with-jpegli`, `--with-jpeg-turbo`, `--without-llvm`,
  `--without-zlib-ng`, `--with-ffi-compat`, `--nightly` / `-c <COMMIT>` / `-r <REF>`

## Architecture

### Repo layout

```
build-windows.sh      # Windows entrypoint: applies patches, builds, reverses patches
build-linux/          # Linux Docker build
  container/          # Dockerfile (ubuntu:jammy, Clang toolchain, Meson/Ninja)
  build/              # Per-dependency shell scripts + build.sh orchestrator + cache/
sbom/                 # sbom.py + per-build catalogs and generated SBOMs (releases/<build>/)
docs/                 # sbom.md, adr/ (architecture decisions), agents/
patch/                # Unified-diff patches applied to the submodule at Windows build time
  vips-all.mk.patch   # Trims the libvips feature set; adds THIRD-PARTY-NOTICES
  openslide.mk.patch  # Points to rainbean/openslide fork, pins 2026-04-13, adds zstd
  libdicom.mk.patch   # Pins libdicom 1.2.0
  mozjpeg.mk.patch    # Disables PNG support in mozjpeg
build-win64-mxe/      # Git submodule (github.com/libvips/build-win64-mxe), pinned to v8.15.5
  build/              # MXE .mk files, overrides.mk (~806 lines of pinned versions), plugins/
  settings/           # Compiler/optimization settings per toolchain
LICENSE, THIRD-PARTY-NOTICES   # LICENSE ships in artifacts; THIRD-PARTY-NOTICES is repo-only
```

### Key design points

- **Linux** uses Clang (`CC=clang`/`CXX=clang++` in `build-linux/build/variables.sh`), builds
  each dependency from source via per-dependency scripts, and bundles a curated `.so` set
  (incl. libpcre, glib stack) in `package.sh` for compatibility on older systems.
- **Windows** uses MXE (LLVM-MinGW by default). Dependency versions are pinned in
  `build-win64-mxe/build/overrides.mk`. The submodule is never edited in place — all local
  changes live as patches in `patch/` and are applied/reversed by `build-windows.sh`.
- **Patches are unified diffs, not file copies.** Regenerate one with:
  `git -C build-win64-mxe diff --src-prefix=a/build-win64-mxe/ --dst-prefix=b/build-win64-mxe/ build/<f>.mk > patch/<f>.mk.patch`
- **The patched `vips-all` build is intentionally trimmed** (modules, fontconfig, heif, jxl,
  magick, matio, nifti, openexr, poppler disabled) to cut runtime dependencies and suppress
  the `vips-magick.dll` warning.
- **Distribution**: every tarball includes `LICENSE`. Distribution SBOMs (CycloneDX, one
  per platform per build) are generated from the released archives by `sbom/sbom.py`
  against a reviewed catalog in `sbom/releases/<build>/` — see `docs/sbom.md` and ADR 0001. `THIRD-PARTY-NOTICES` is **not** bundled in artifacts by design — on Windows
  `build-windows.sh` stages it into the submodule build dir and `vips-all.mk.patch` copies it
  into `vips-packaging`, but the submodule's `package-vipsdev.sh` only zips a fixed whitelist
  (`ChangeLog,LICENSE,README.md,versions.json`), so the notices file is intentionally dropped.

### Version pinning

libvips is pinned to **8.15.5** on both platforms (Linux: `build-linux/build/libvips.sh`;
Windows: submodule tag). A bump to 8.18.2 was attempted and **rolled back** to 8.15.5 — treat
re-bumps as deliberate, version-sensitive changes, not routine updates.

Authoritative version sources (don't trust a hardcoded list — read these):
- Linux deps: the per-dependency scripts in `build-linux/build/` (each pins its version near
  the top, e.g. `cmake.sh`, `zlib.sh`, `lcms.sh`, `openjpeg.sh`, `libspng.sh`, `mozjpeg.sh`,
  `libtiff.sh`, `libdicom.sh`, `openslide.sh`, `libvips.sh`).
- Windows deps: `build-win64-mxe/build/overrides.mk` and the `patch/*.mk.patch` files.

## Agent skills

### Issue tracker

Issues live in GitHub Issues on `rainbean/build-vips`, managed with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default labels are used as-is (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` and `docs/adr/` at the repo root, created only when needed. See `docs/agents/domain.md`.
