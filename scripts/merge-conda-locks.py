#!/usr/bin/env python3
"""Merge native single-platform conda-lock files deterministically."""
from __future__ import annotations

import pathlib
import sys

import yaml


def main() -> int:
    if len(sys.argv) < 3:
        raise SystemExit("Usage: merge-conda-locks.py OUTPUT INPUT...")
    output = pathlib.Path(sys.argv[1])
    inputs = [pathlib.Path(value) for value in sys.argv[2:]]
    documents = [yaml.safe_load(path.read_text()) for path in inputs]
    first = documents[0]
    packages: dict[tuple[str, str, str, str, str], dict] = {}
    platforms: set[str] = set()
    content_hash: dict[str, str] = {}
    for document in documents:
        if document.get("version") != first.get("version"):
            raise SystemExit("cannot merge lockfiles with different formats")
        content_hash.update(document.get("metadata", {}).get("content_hash", {}))
        for package in document.get("package", []):
            platform = package.get("platform", "")
            platforms.add(platform)
            key = tuple(str(package.get(field, "")) for field in ("manager", "platform", "name", "version", "build"))
            packages[key] = package
    merged = dict(first)
    merged["package"] = [packages[key] for key in sorted(packages)]
    metadata = merged.setdefault("metadata", {})
    metadata["content_hash"] = content_hash
    metadata["platforms"] = sorted(platforms)
    metadata["sources"] = ["environment.yml"]
    output.write_text(yaml.safe_dump(merged, sort_keys=False, allow_unicode=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
