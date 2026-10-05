#!/usr/bin/env python3
"""Generate distribution SBOMs (CycloneDX 1.6) for released vips packages.

The SBOM is built from the released archive, not from the build scripts:
every distributed file is inventoried and hashed, mapped to exactly one
component of a reviewed catalog, and its ELF/PE imports are read to derive
the dependency graph and the host requirements. See docs/sbom.md and
docs/adr/0001-sbom-from-released-archives.md.

    sbom/sbom.py generate sbom/releases/<build>         # both platforms
    sbom/sbom.py generate sbom/releases/<build> linux   # one platform
    sbom/sbom.py resolve-debs sbom/releases/<build>     # pin Ubuntu revisions

Standard library only (Python 3.11+). Archives are read in place, never
extracted, and fetched with `aws s3 cp` when they are not in the release
directory or --archives.
"""

import argparse
import fnmatch
import hashlib
import io
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tarfile
import tomllib
import urllib.request
import uuid
import zipfile
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

PLATFORMS = ("linux", "windows")
TOOL_NAME = "build-vips sbom.py"
PROP = "aixmed:"  # namespace for our CycloneDX properties
CACHE = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "build-vips-sbom"
ARCHIVE_CACHE = CACHE / "archives"


class CatalogError(Exception):
    pass


# --------------------------------------------------------------------------
# Archive inventory


@dataclass
class Member:
    path: str  # relative to the archive scope
    kind: str  # "file", "symlink" or "hardlink"
    size: int = 0
    sha256: str = ""
    target: str = ""  # link target for symlinks and hardlinks
    data: bytes = field(default=b"", repr=False)


def read_archive(path, scope):
    """Return the distributed members of an archive, keyed by scoped path.

    `scope` is a directory prefix inside the archive ("" for the whole
    archive). Members outside it are not distributed and are skipped.
    """
    prefix = scope.rstrip("/") + "/" if scope else ""
    members = {}

    def add(name, member):
        if not name.startswith(prefix) or name == prefix:
            return
        member.path = name[len(prefix):]
        # package.sh appends libjpeg twice, so the tar holds a second copy of
        # each libjpeg path as a hardlink to itself; keep the real entry
        if member.kind == "hardlink" and member.target.removeprefix("./") == name:
            return
        members[member.path] = member

    if tarfile.is_tarfile(path):
        with tarfile.open(path) as tar:
            for info in tar:
                name = info.name.removeprefix("./")
                if info.isdir():
                    continue
                if info.issym():
                    add(name, Member(name, "symlink", target=info.linkname))
                elif info.islnk():
                    add(name, Member(name, "hardlink", target=info.linkname))
                elif info.isfile():
                    data = tar.extractfile(info).read()
                    add(name, Member(name, "file", len(data),
                                     hashlib.sha256(data).hexdigest(), data=data))
    elif zipfile.is_zipfile(path):
        with zipfile.ZipFile(path) as zf:
            for info in zf.infolist():
                if info.is_dir():
                    continue
                data = zf.read(info)
                add(info.filename, Member(info.filename, "file", len(data),
                                          hashlib.sha256(data).hexdigest(), data=data))
    else:
        raise CatalogError(f"{path}: not a tar or zip archive")

    # a hardlink is the same bytes as its target
    for m in members.values():
        if m.kind == "hardlink":
            t = members.get(m.target.removeprefix("./").removeprefix(prefix))
            if t:
                m.sha256, m.size = t.sha256, t.size
    return members


def read_archive_file(path, name):
    """Read one member (e.g. versions.json) from anywhere in an archive."""
    if zipfile.is_zipfile(path):
        with zipfile.ZipFile(path) as zf:
            return zf.read(name)
    with tarfile.open(path) as tar:
        return tar.extractfile(name).read()


# --------------------------------------------------------------------------
# Binary imports: minimal ELF and PE readers


def elf_dynamic(data):
    """Return (soname, [needed]) for an ELF64 little-endian shared object."""
    if data[:4] != b"\x7fELF" or data[4] != 2 or data[5] != 1:
        return None
    phoff, = struct.unpack_from("<Q", data, 0x20)
    phentsize, phnum = struct.unpack_from("<HH", data, 0x36)
    loads, dynamic = [], None
    for i in range(phnum):
        p_type, _, p_offset, p_vaddr, _, p_filesz, _, _ = struct.unpack_from(
            "<IIQQQQQQ", data, phoff + i * phentsize)
        if p_type == 1:
            loads.append((p_vaddr, p_offset, p_filesz))
        elif p_type == 2:
            dynamic = (p_offset, p_filesz)
    if dynamic is None:
        return (None, [])

    def vaddr_to_offset(addr):
        for vaddr, offset, size in loads:
            if vaddr <= addr < vaddr + size:
                return addr - vaddr + offset
        raise CatalogError(f"ELF address {addr:#x} is not mapped")

    entries = []
    off, end = dynamic[0], dynamic[0] + dynamic[1]
    while off + 16 <= end:
        tag, val = struct.unpack_from("<qQ", data, off)
        if tag == 0:
            break
        entries.append((tag, val))
        off += 16
    strtab = vaddr_to_offset(next(v for t, v in entries if t == 5))

    def string(index):
        start = strtab + index
        return data[start:data.index(b"\0", start)].decode()

    needed = [string(v) for t, v in entries if t == 1]
    soname = next((string(v) for t, v in entries if t == 14), None)
    return (soname, needed)


def pe_imports(data):
    """Return the DLL names a PE image imports (normal and delay-load)."""
    if data[:2] != b"MZ":
        return None
    pe, = struct.unpack_from("<I", data, 0x3C)
    if data[pe:pe + 4] != b"PE\0\0":
        return None
    nsections, = struct.unpack_from("<H", data, pe + 6)
    opt_size, = struct.unpack_from("<H", data, pe + 20)
    opt = pe + 24
    magic, = struct.unpack_from("<H", data, opt)
    ddir = opt + (112 if magic == 0x20B else 96)
    sections = []
    for i in range(nsections):
        s = opt + opt_size + i * 40
        vsize, vaddr, rawsize, rawptr = struct.unpack_from("<IIII", data, s + 8)
        sections.append((vaddr, max(vsize, rawsize), rawptr))

    def rva_to_offset(rva):
        for vaddr, size, rawptr in sections:
            if vaddr <= rva < vaddr + size:
                return rva - vaddr + rawptr
        raise CatalogError(f"PE RVA {rva:#x} is not mapped")

    def cstring(rva):
        start = rva_to_offset(rva)
        return data[start:data.index(b"\0", start)].decode()

    names = []
    for index, size, name_at in ((1, 20, 12), (13, 32, 4)):  # import, delay import
        rva, _ = struct.unpack_from("<II", data, ddir + index * 8)
        if not rva:
            continue
        off = rva_to_offset(rva)
        while True:
            desc = data[off:off + size]
            if not any(desc):
                break
            names.append(cstring(struct.unpack_from("<I", desc, name_at)[0]))
            off += size
    return names


# --------------------------------------------------------------------------
# Catalog


def load_catalog(release_dir, platform):
    path = release_dir / f"{platform}.toml"
    if not path.exists():
        raise CatalogError(f"{path}: missing")
    with path.open("rb") as f:
        cat = tomllib.load(f)
    shared = release_dir / "release.toml"
    if shared.exists():
        with shared.open("rb") as f:
            base = tomllib.load(f)
        cat["properties"] = {**base.get("properties", {}), **cat.get("properties", {})}
        cat.setdefault("manufacturer", base.get("manufacturer"))
    cat["_path"] = path
    return cat


def normalize_license(expr):
    """Turn Cargo-style "MIT/Apache-2.0" into an SPDX expression."""
    expr = re.sub(r"\s*/\s*", " OR ", expr.strip())
    return expr


def is_gpl(expr):
    """True when every alternative of an SPDX expression is GPL/AGPL.

    "GPL-2.0-or-later" is flagged; "BSD-3-Clause OR GPL-2.0-only" (zstd) is
    not, because the recipient can take the permissive alternative.
    """
    alternatives = re.split(r"\s+OR\s+", expr.strip("() "))
    return all(re.search(r"(?<![L])\b(A?GPL)-", a) for a in alternatives)


def cargo_tree_components(path, exclude):
    """Read `cargo tree -f '{p}|{l}' --prefix none` output into crate entries."""
    crates = []
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "|" not in line:
            continue
        pkg, lic = line.split("|", 1)
        name, version = pkg.split()[:2]
        version = version.removeprefix("v")
        if name in exclude:
            continue
        crates.append({
            "name": name,
            "version": version,
            "license": normalize_license(lic),
            "purl": f"pkg:cargo/{name}@{version}",
            "bom_ref": f"crate:{name}@{version}",
            "source": f"https://crates.io/crates/{name}/{version}",
        })
    return crates


# --------------------------------------------------------------------------
# SBOM assembly


def license_entry(expr):
    expr = expr.strip()
    if " " not in expr and not expr.startswith("LicenseRef-"):
        return [{"license": {"id": expr}}]
    return [{"expression": expr}]


def component_purl(comp, cat):
    if "purl" in comp:
        return comp["purl"]
    deb = comp.get("deb")
    if deb:
        distro = cat["debian"]["distro"]
        return f"pkg:deb/ubuntu/{deb['source']}@{deb['version']}?arch=source&distro={distro}"
    return None


def build_component(comp, cat, occurrences=None, linkage="dynamic", evidence=None):
    purl = component_purl(comp, cat)
    ref = comp.get("bom_ref", f"{comp['name']}@{comp['version']}")
    out = {
        "bom-ref": ref,
        "type": comp.get("type", "library"),
        "name": comp["name"],
        "version": comp["version"],
    }
    if comp.get("description"):
        out["description"] = comp["description"]
    out["licenses"] = license_entry(comp["license"])
    if purl:
        out["purl"] = purl
    refs = []
    if comp.get("source"):
        refs.append({"type": "distribution", "url": comp["source"]})
    if comp.get("vcs"):
        refs.append({"type": "vcs", "url": comp["vcs"]})
    if comp.get("website"):
        refs.append({"type": "website", "url": comp["website"]})
    if refs:
        out["externalReferences"] = refs

    props = [{"name": PROP + "linkage", "value": linkage}]
    if is_gpl(comp["license"]):
        props.append({"name": PROP + "license-flag", "value": "GPL"})
    deb = comp.get("deb")
    if deb:
        props.append({"name": PROP + "deb-packages", "value": ", ".join(deb["binaries"])})
    for note in comp.get("notes", []):
        props.append({"name": PROP + "note", "value": note})
    out["properties"] = props

    if occurrences is not None:
        regular = [m for m in occurrences if m.kind != "symlink"]
        if len({m.sha256 for m in regular}) == 1:
            out["hashes"] = [{"alg": "SHA-256", "content": regular[0].sha256}]
        occ = []
        for m in occurrences:
            if m.kind == "symlink":
                ctx = f"symlink -> {m.target}"
            else:
                ctx = f"sha256:{m.sha256} size:{m.size}"
            occ.append({"location": m.path, "additionalContext": ctx})
        out["evidence"] = {"occurrences": occ}
    if evidence:
        out.setdefault("evidence", {})["identity"] = [{
            "field": "name",
            "confidence": 1,
            "methods": [{"technique": "binary-analysis" if evidence.get("binary") else "other",
                         "confidence": 1,
                         "value": evidence["text"]}],
        }]
    return out


def generate(release_dir, platform, archives_dir, timestamp):
    cat = load_catalog(release_dir, platform)
    archive = locate_archive(cat["archive"], release_dir, archives_dir)
    digest = sha256_file(archive)
    if digest != cat["archive"]["sha256"]:
        raise CatalogError(f"{archive}: SHA-256 {digest} does not match the catalog")

    members = read_archive(archive, cat["archive"].get("scope", ""))
    errors = []

    # map every distributed file to exactly one component
    owner = {}
    for i, comp in enumerate(cat["component"]):
        for pattern in comp.get("files", []):
            hits = [p for p in members if fnmatch.fnmatchcase(p, pattern)]
            if not hits:
                errors.append(f"{comp['name']}: pattern {pattern!r} matches no file")
            for p in hits:
                if p in owner and owner[p] != i:
                    errors.append(f"{p}: claimed by {cat['component'][owner[p]]['name']} "
                                  f"and {comp['name']}")
                owner[p] = i
    for p in sorted(set(members) - set(owner)):
        errors.append(f"{p}: shipped but not mapped to a component")
    for comp in cat["component"]:
        if not comp.get("files") and not comp.get("embedded_in"):
            errors.append(f"{comp['name']}: no shipped file and not embedded")
        for host in comp.get("embedded_in", []):
            if host not in members:
                errors.append(f"{comp['name']}: embedded_in {host!r} is not shipped")

    # cross-check versions against a manifest shipped in the archive
    manifest = cat["archive"].get("versions_json")
    if manifest:
        versions = json.loads(read_archive_file(archive, manifest))
        claimed = set(cat["archive"].get("versions_json_ignore", []))
        for comp in iter_all_components(cat):
            key = comp.get("versions_key")
            if not key:
                continue
            claimed.add(key)
            expected = comp.get("versions_value", comp["version"])
            if versions.get(key) != expected:
                errors.append(f"{comp['name']}: catalog says {expected}, "
                              f"{manifest} says {versions.get(key)}")
        for key in sorted(set(versions) - claimed):
            errors.append(f"{manifest}: {key} {versions[key]} not claimed by any component")

    # binary imports -> dependency graph and host requirements
    by_name = {}
    for p, m in members.items():
        by_name.setdefault(os.path.basename(p).lower(), p)
    imports = {}
    for p, m in members.items():
        if m.kind != "file":
            continue
        elf = elf_dynamic(m.data)
        if elf is not None:
            soname, needed = elf
            imports[p] = needed
            if soname:
                by_name.setdefault(soname.lower(), p)
            continue
        pe = pe_imports(m.data)
        if pe is not None:
            imports[p] = pe
    host = {}
    depends = {}
    for p, names in imports.items():
        for n in names:
            target = by_name.get(n.lower())
            if target is None:
                host.setdefault(n, []).append(p)
                continue
            a, b = owner.get(p), owner.get(target)
            if a is not None and b is not None and a != b:
                depends.setdefault(a, set()).add(b)

    if errors:
        raise CatalogError("\n".join(errors))

    # components
    bom_components = []
    refs = {}
    static_edges = []  # (host ref, [embedded refs])
    for i, comp in enumerate(cat["component"]):
        if comp.get("embedded_in"):
            occ = [members[h] for h in comp["embedded_in"]]
            entry = build_component(comp, cat, occ, "static", comp.get("evidence"))
        else:
            occ = [members[p] for p in sorted(members) if owner.get(p) == i]
            entry = build_component(comp, cat, occ, "dynamic")
        nested = [build_component(sub, cat, None, "static", sub.get("evidence"))
                  for sub in comp.get("static", [])]
        nested += [build_component(c, cat, None, "static")
                   for c in load_static_list(comp, release_dir)]
        if nested:
            entry["components"] = nested
            static_edges.append((entry["bom-ref"], [n["bom-ref"] for n in nested]))
        refs[i] = entry["bom-ref"]
        bom_components.append(entry)

    root_ref = f"{cat['sbom']['name']}@{cat['sbom']['version']}"
    dependencies = [{"ref": root_ref, "dependsOn": [refs[i] for i in range(len(refs))]}]
    embedded = dict(static_edges)
    for i in range(len(refs)):
        on = sorted(refs[j] for j in depends.get(i, ())) + embedded.pop(refs[i], [])
        dependencies.append({"ref": refs[i], "dependsOn": on})
    for ref, on in embedded.items():
        dependencies.append({"ref": ref, "dependsOn": on})
    # every nested component needs its own entry to appear in the graph
    listed = {d["ref"] for d in dependencies}
    for on in dict(static_edges).values():
        for ref in on:
            if ref not in listed:
                dependencies.append({"ref": ref, "dependsOn": []})
                listed.add(ref)

    props = [{"name": PROP + k, "value": str(v)} for k, v in cat.get("properties", {}).items()]
    props += [
        {"name": PROP + "archive", "value": cat["archive"]["file"]},
        {"name": PROP + "archive-url", "value": cat["archive"].get("url", "")},
        {"name": PROP + "archive-sha256", "value": digest},
        {"name": PROP + "archive-scope", "value": cat["archive"].get("scope", "") or "(whole archive)"},
        {"name": PROP + "distributed-files", "value": str(len(members))},
        {"name": PROP + "catalog", "value": str(cat["_path"].resolve().relative_to(repo_root()))},
    ]
    for name in sorted(host, key=str.lower):
        needers = sorted({os.path.basename(p) for p in host[name]})
        props.append({"name": PROP + "host-requirement",
                      "value": f"{name} (imported by {', '.join(needers)})"})

    serial = uuid.uuid5(uuid.NAMESPACE_URL,
                        f"build-vips-sbom:{digest}:{sha256_file(cat['_path'])}")
    bom = {
        "$schema": "http://cyclonedx.org/schema/bom-1.6.schema.json",
        "bomFormat": "CycloneDX",
        "specVersion": "1.6",
        "serialNumber": f"urn:uuid:{serial}",
        "version": 1,
        "metadata": {
            "timestamp": timestamp,
            "lifecycles": [{"phase": "post-build"}],
            **({"manufacturer": cat["manufacturer"]} if cat.get("manufacturer") else {}),
            "tools": {"components": [{"type": "application", "name": TOOL_NAME,
                                      "version": tool_version()}]},
            "component": {
                "bom-ref": root_ref,
                "type": "application",
                "name": cat["sbom"]["name"],
                "version": cat["sbom"]["version"],
                "description": cat["sbom"].get("description", ""),
                "hashes": [{"alg": "SHA-256", "content": digest}],
            },
            "properties": props,
        },
        "components": bom_components,
        "dependencies": dependencies,
    }
    out = release_dir / cat["sbom"]["output"]
    out.write_text(json.dumps(bom, indent=2, ensure_ascii=False) + "\n")
    return out, len(members), count_components(bom_components), host


def iter_all_components(cat):
    for comp in cat["component"]:
        yield comp
        yield from comp.get("static", [])


def load_static_list(sub, release_dir):
    spec = sub.get("cargo_tree")
    if not spec:
        return []
    return cargo_tree_components(release_dir / spec["file"], set(spec.get("exclude", [])))


def count_components(components):
    return sum(1 + count_components(c.get("components", [])) for c in components)


# --------------------------------------------------------------------------
# Debian revision resolution (Linux packages copied from Ubuntu)

LAUNCHPAD = "https://api.launchpad.net/devel/ubuntu"


def http_json(url):
    with urllib.request.urlopen(url, timeout=60) as r:
        return json.load(r)


def deb_members(deb):
    """Yield (path, bytes) for regular files in a .deb's data archive."""
    if deb[:8] != b"!<arch>\n":
        raise CatalogError("not a .deb archive")
    off = 8
    while off < len(deb):
        name = deb[off:off + 16].decode().strip().rstrip("/")
        size = int(deb[off + 48:off + 58].decode().strip())
        body = deb[off + 60:off + 60 + size]
        off += 60 + size + (size & 1)
        if not name.startswith("data.tar"):
            continue
        if name.endswith(".zst"):
            zstd = shutil.which("zstd")
            if not zstd:
                raise CatalogError("data.tar.zst needs the zstd command")
            body = subprocess.run([zstd, "-dc"], input=body, capture_output=True,
                                  check=True).stdout
        with tarfile.open(fileobj=io.BytesIO(body)) as tar:
            for info in tar:
                if info.isfile():
                    yield info.name.removeprefix("./"), tar.extractfile(info).read()


def resolve_debs(release_dir, archives_dir, cache_dir):
    """Find the Ubuntu package revision whose files match the shipped bytes."""
    cat = load_catalog(release_dir, "linux")
    series = cat["debian"]["series"]
    archive = locate_archive(cat["archive"], release_dir, archives_dir)
    members = read_archive(archive, cat["archive"].get("scope", ""))
    cache_dir.mkdir(parents=True, exist_ok=True)
    arch_series = f"{LAUNCHPAD}/{series}/amd64"
    ok = True
    for comp in cat["component"]:
        deb = comp.get("deb")
        if not deb:
            continue
        files = {}
        for pattern in comp["files"]:
            for p, m in members.items():
                if fnmatch.fnmatchcase(p, pattern) and m.kind == "file":
                    files[os.path.basename(p)] = m.sha256
        matched = {}
        for binary in deb["binaries"]:
            q = (f"{LAUNCHPAD}/+archive/primary?ws.op=getPublishedBinaries"
                 f"&binary_name={binary}&exact_match=true&distro_arch_series={arch_series}")
            pubs = http_json(q)["entries"]
            seen = set()
            for pub in sorted(pubs, key=lambda p: p["date_published"] or "", reverse=True):
                v = pub["binary_package_version"]
                if v in seen:
                    continue
                seen.add(v)
                for url in http_json(pub["self_link"] + "?ws.op=binaryFileUrls"):
                    local = cache_dir / url.rsplit("/", 1)[1]
                    if not local.exists():
                        with urllib.request.urlopen(url, timeout=300) as r:
                            local.write_bytes(r.read())
                    for path, data in deb_members(local.read_bytes()):
                        base = os.path.basename(path)
                        if base in files and hashlib.sha256(data).hexdigest() == files[base]:
                            matched[base] = (binary, v, pub["source_package_name"],
                                             pub["source_package_version"])
                if all(f in matched for f in files):
                    break
        missing = sorted(set(files) - set(matched))
        sources = {(m[2], m[3]) for m in matched.values()}
        status = "OK"
        if missing or len(sources) != 1:
            status, ok = "UNRESOLVED", False
        elif sources != {(deb["source"], deb["version"])}:
            status, ok = "CATALOG DIFFERS", False
        print(f"{comp['name']}: {status}")
        for base in sorted(files):
            m = matched.get(base)
            print(f"  {base}: " + (f"{m[0]} {m[1]} (source {m[2]} {m[3]})" if m
                                   else "no published package has these bytes"))
    return ok


# --------------------------------------------------------------------------
# Helpers


def repo_root():
    return Path(__file__).resolve().parent.parent


def tool_version():
    try:
        return subprocess.run(["git", "-C", str(repo_root()), "rev-parse", "--short", "HEAD"],
                              capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def locate_archive(spec, release_dir, archives_dir):
    for d in filter(None, (archives_dir, release_dir)):
        p = Path(d) / spec["file"]
        if p.exists():
            return p
    url = spec.get("url", "")
    if not url.startswith("s3://"):
        raise CatalogError(f"{spec['file']}: not found locally and no s3:// url to fetch")
    dest = Path(archives_dir) / spec["file"]
    dest.parent.mkdir(parents=True, exist_ok=True)
    print(f"fetching {url}", file=sys.stderr)
    subprocess.run(["aws", "s3", "cp", "--only-show-errors", url, str(dest)], check=True)
    return dest


def validate(path):
    tool = shutil.which("cdx-validate")
    if not tool:
        print(f"  not validated: cdx-validate not found "
              f"(npm install -g @cyclonedx/cdxgen)", file=sys.stderr)
        return None
    r = subprocess.run([tool, "-i", str(path), "--strict", "--no-deep", "--fail-severity",
                        "critical", "--no-include-manual"], capture_output=True, text=True)
    if r.returncode != 0:
        print(r.stdout + r.stderr, file=sys.stderr)
    return r.returncode == 0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    g = sub.add_parser("generate", help="write the SBOM(s) for a release")
    g.add_argument("release", type=Path, help="release catalog directory")
    g.add_argument("platform", nargs="*", help="linux and/or windows (default: both)")
    g.add_argument("--archives", type=Path, default=ARCHIVE_CACHE,
                   help=f"where archives are found or fetched to (default {ARCHIVE_CACHE})")
    g.add_argument("--no-validate", action="store_true")
    r = sub.add_parser("resolve-debs", help="match Linux Ubuntu files to package revisions")
    r.add_argument("release", type=Path)
    r.add_argument("--archives", type=Path, default=ARCHIVE_CACHE)
    r.add_argument("--cache", type=Path, default=CACHE / "debs", help="downloaded .deb cache")
    args = ap.parse_args()

    try:
        if args.cmd == "resolve-debs":
            sys.exit(0 if resolve_debs(args.release, args.archives, args.cache) else 1)
        epoch = os.environ.get("SOURCE_DATE_EPOCH")
        now = datetime.fromtimestamp(int(epoch), timezone.utc) if epoch else datetime.now(timezone.utc)
        timestamp = now.replace(microsecond=0).isoformat().replace("+00:00", "Z")
        for platform in args.platform:
            if platform not in PLATFORMS:
                ap.error(f"unknown platform {platform!r}; choose from {', '.join(PLATFORMS)}")
        failed = False
        for platform in args.platform or PLATFORMS:
            out, nfiles, ncomp, host = generate(args.release, platform, args.archives, timestamp)
            print(f"{platform}: {out} ({nfiles} files, {ncomp} components, "
                  f"{len(host)} host requirements)")
            if not args.no_validate and validate(out) is False:
                failed = True
        sys.exit(1 if failed else 0)
    except CatalogError as e:
        sys.exit(f"error: {e}")


if __name__ == "__main__":
    main()
