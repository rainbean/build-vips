# 1. Distribution SBOMs are generated from the released archive against a reviewed catalog

- Status: accepted
- Date: 2026-10-05

## Context

The SBOM shipped with decart 2.7.5 (`SBOM-LibVIPS-v8.15.2-2024-12-10.json`) came from
running `cdxgen` over the Windows build tree. It listed 937 components: 657 Rust crates and
280 unversioned names, all from the MXE toolchain under `build-win64-mxe/build/mxe/usr`. It
had no libvips or openslide entry, no versions for the C libraries, and it described neither
platform's shipped files.

Three properties of this repo make a scanner-based SBOM wrong in principle, not just noisy:

- The two platforms are built differently (Linux: Docker, source scripts and libraries copied
  from Ubuntu; Windows: MXE cross-compilation) and ship different component sets and versions.
- What is distributed is a subset of what is built. Linux ships the whole tarball. Windows
  ships only `vips-dev-8.15/bin/`, because decart's `install.ps1` deletes the rest. Build tools,
  headers and import libraries are not distributed.
- The build is not reproducible from git. MXE is cloned from `master` unpinned, and `package.sh`
  copies whatever Ubuntu revision was current when the build image was made. Only the
  released files say what shipped.

## Decision

**One SBOM per platform per build, never merged.** Both are CycloneDX 1.6 JSON, written by
`sbom/sbom.py generate sbom/releases/<build>`, which covers both platforms in one command.

**The released archive is the evidence.** The generator reads the archive named in the
catalog, checks its SHA-256, and inventories every distributed file (the whole tarball on
Linux, `bin/` on Windows) with its hash.

**A reviewed catalog per build supplies what binaries cannot.** `sbom/releases/<build>/`
holds `linux.toml` and `windows.toml`. They map file globs to components, each with its
version, SPDX license, purl and source URL. The generator refuses to write an SBOM unless:
every distributed file maps to exactly one component; every component owns a shipped file or
is embedded in one; and on Windows, every entry of the shipped `versions.json` agrees with the
catalog. A new build that adds, drops or bumps a library therefore fails until the catalog is
updated, so stale SBOMs can't be produced silently.

**Dependencies and host requirements are derived, not written down.** ELF `DT_NEEDED` and PE
import tables give the dependency graph. Any import that resolves to no shipped file is
recorded as an `aixmed:host-requirement` in `metadata.properties`, not as a component.

**Statically embedded code is listed.** It is nested under its host component, with evidence
of how it was established (symbols, strings, or the build configuration). Code embedded in
several hosts (proxy-libintl on Windows) is a top-level component with `aixmed:linkage=static`
and an occurrence for each host.

**Ubuntu copies are pinned by bytes.** `sbom.py resolve-debs` finds the focal package revision
whose files are byte-identical to the shipped ones, using Launchpad. The purl names the Debian
*source* package (`pkg:deb/ubuntu/<source>@<revision>?arch=source&distro=…`), because Ubuntu
security advisories are keyed by source package.

**Licenses are confirmed against upstream source at the pinned version.** They are written as
SPDX expressions. A component whose every license alternative is GPL gets
`aixmed:license-flag=GPL`. The SBOM records the fact; whether it is acceptable is the owner's
call.

**Out of scope:** build tools; and toolchain startup objects linked into every binary (glibc
and libgcc crt files on Linux, mingw-w64 CRT and compiler-rt builtins on Windows). The
toolchain runtimes that ship as files (LLVM `libc++.dll` and `libunwind.dll`) are in scope.

## Consequences

- Each released build needs a catalog. Most builds can copy the previous one and change only
  the versions and hashes the generator reports.
- The generator is offline and uses only the Python standard library. The network is used
  only to fetch archives from S3, by `resolve-debs`, and to refresh the librsvg crate list.
- The librsvg crate list is resolved from `Cargo.lock` for the target, because the DLL is
  stripped. It is an upper bound, since the linker may drop unused crates.
- `cdxgen` stays useful for scanning source trees. It is no longer how distribution SBOMs are made.

## Alternatives considered

- **Scan the build tree (`cdxgen`, `syft`).** Rejected. These tools find toolchain and
  build-time packages, cannot version C libraries built from tarballs, and cannot tell what is
  shipped.
- **Derive the SBOM from the build scripts.** Rejected. MXE is unpinned, and the Ubuntu revisions
  are invisible to the scripts. The scripts describe the intent, not the release.
- **One merged SBOM for both platforms.** Rejected. The same component name would carry two
  versions, and consumers could not tell which platform ships what.
