#!/usr/bin/env python3
"""Build and verify the exact closed-manifest GDAM release archive."""

from __future__ import annotations

import hashlib
import pathlib
import stat
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
ADDON = ROOT / "addon"
MANIFEST = ROOT / "package" / "manifest.txt"


def entries() -> list[str]:
    result = [line.strip() for line in MANIFEST.read_text().splitlines() if line.strip()]
    if len(result) != len(set(result)):
        raise SystemExit("duplicate package manifest entry")
    return result


def validate_source(names: list[str]) -> None:
    actual = sorted(
        str(path.relative_to(ADDON))
        for path in ADDON.rglob("*")
        if path.is_file() or path.is_symlink()
    )
    if actual != sorted(names):
        raise SystemExit(f"closed manifest mismatch: expected={sorted(names)!r} actual={actual!r}")
    for name in names:
        path = ADDON / name
        if path.is_symlink():
            raise SystemExit(f"symlink rejected: {name}")
        if not path.is_file():
            raise SystemExit(f"missing package file: {name}")


def build(output: pathlib.Path) -> None:
    names = entries()
    validate_source(names)
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for name in names:
            info = zipfile.ZipInfo(name, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = (stat.S_IFREG | 0o644) << 16
            archive.writestr(info, (ADDON / name).read_bytes())
    verify(output)


def verify(archive_path: pathlib.Path) -> None:
    expected = sorted(entries())
    with zipfile.ZipFile(archive_path) as archive:
        infos = archive.infolist()
        actual = sorted(info.filename for info in infos)
        if actual != expected or len(actual) != len(set(actual)):
            raise SystemExit(f"archive manifest mismatch: expected={expected!r} actual={actual!r}")
        for info in infos:
            pure = pathlib.PurePosixPath(info.filename)
            if pure.is_absolute() or ".." in pure.parts or "\\" in info.filename:
                raise SystemExit(f"unsafe archive path: {info.filename}")
            mode = info.external_attr >> 16
            if stat.S_ISLNK(mode) or not stat.S_ISREG(mode):
                raise SystemExit(f"non-regular archive entry: {info.filename}")
    digest = hashlib.sha256(archive_path.read_bytes()).hexdigest()
    print(f"PACKAGE_VERIFIED {archive_path} sha256:{digest} files:{len(expected)}")


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in {"build", "verify"}:
        raise SystemExit(f"usage: {sys.argv[0]} build|verify ARCHIVE")
    target = pathlib.Path(sys.argv[2]).resolve()
    build(target) if sys.argv[1] == "build" else verify(target)
