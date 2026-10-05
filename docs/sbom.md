# Distribution SBOMs

Every released build gets two CycloneDX 1.6 SBOMs, one for Linux and one for Windows. Both are
generated from the released archives by one command:

```bash
sbom/sbom.py generate sbom/releases/<build>
```

Why it works this way, and what is in or out of scope, is recorded in
[ADR 0001](adr/0001-sbom-from-released-archives.md).

## Requirements

- Python 3.11+ (standard library only).
- `aws` CLI with AIxMed credentials, when the archives aren't already in
  `~/.cache/build-vips-sbom/archives/` (override the location with `--archives DIR`).
- `cdx-validate` for schema validation (`npm install -g @cyclonedx/cdxgen`). Without it the SBOM
  is still written, but it isn't validated. Pass `--no-validate` to skip validation.
- `zstd`, only for `resolve-debs` against Ubuntu releases newer than focal, whose `.deb` files
  use zstd.

## Layout

```
sbom/
  sbom.py                         generator; also `resolve-debs`
  releases/<build>/
    release.toml                  provenance shared by both platforms (commit, decart release)
    linux.toml, windows.toml      catalogs: archive, scope, components
    windows-librsvg-crates.txt    Rust crates linked into librsvg (evidence)
    SBOM-LibVIPS-<platform>-<vips>-<build>.cdx.json   generated output
```

`<build>` is the build date that names the archives, e.g. `2024-12-10` for
`vips-linux-2024-12-10.tar.gz` and `vips-w64-2024-12-10.zip`.

## Making SBOMs for a new build

1. **Copy the previous catalog.** `cp -r sbom/releases/<previous> sbom/releases/<build>`. Then edit
   `release.toml` (build-vips commit, decart release, date) and each platform's `[sbom]` and
   `[archive]` (file name, `s3://` URL, SHA-256 from `sha256sum`).
2. **Run the generator and fix what it reports.**
   `sbom/sbom.py generate sbom/releases/<build>`. It downloads the archives, then lists every
   problem it finds: a shipped file that matches no component, a glob that matches nothing, or
   a version that disagrees with the shipped `versions.json`. Update the component (version,
   source URL, license if upstream changed it) until it passes. Take versions from the per-dep
   scripts (`build-linux/build/<dep>.sh`) and `build-win64-mxe/build/overrides.mk` at the build
   commit.
3. **Pin the Ubuntu packages (Linux).** For each component with a `deb` entry, clear the
   revision if the build image changed, then run
   `sbom/sbom.py resolve-debs sbom/releases/<build>`. It prints the package revision whose
   bytes match each shipped file. Copy the revisions into `linux.toml` and re-run it until
   every component shows `OK`. For a build on a newer Ubuntu, update `[debian]` (`series`,
   `distro`) first.
4. **Refresh the librsvg crates (Windows), if librsvg changed.** From the librsvg release
   tarball, run the `cargo tree` command recorded at the top of `windows-librsvg-crates.txt`
   and replace the file.
5. **Check embedded code.** A new static dependency won't show up as a file. Look at the
   generator's host-requirement output and at what the build links statically (see
   `[[component.static]]` entries and their `evidence`).
6. **Review the diff of the generated SBOMs and commit** the catalog together with the output.
   Upload the SBOMs wherever the release needs them.

To regenerate just one platform: `sbom/sbom.py generate sbom/releases/<build> linux`.

## Reading the output

- `metadata.component` is the package. Its hash is the archive's SHA-256.
- `metadata.properties` (`aixmed:*`) hold provenance and every `host-requirement`: an import
  that no shipped file satisfies, with the files that need it.
- Each component lists its shipped files under `evidence.occurrences`. Regular files carry
  their SHA-256, and symlinks carry their target. `hashes` is set when the component is a
  single file.
- `aixmed:linkage` is `dynamic` (shipped as files) or `static` (compiled into a host).
- `aixmed:license-flag=GPL` marks components whose every license alternative is GPL.
- `dependencies` comes from the binaries' import tables, plus host → embedded edges.

## Builds covered

| Build | decart | build-vips commit | Notes |
|---|---|---|---|
| [2024-12-10](../sbom/releases/2024-12-10/) | 2.7.5 | `7a7f992` | made retroactively from the S3 archives; Linux focal base, Windows ships GPL FFTW and Poppler |
