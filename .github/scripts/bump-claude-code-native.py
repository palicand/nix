#!/usr/bin/env python3
"""Bump pkgs/claude-code-native/default.nix to the latest claude-code release.

Polls https://downloads.claude.ai/claude-code-releases/latest, compares against
the pinned version, and on drift rewrites the version + per-platform sha256
hashes in place. Designed for GitHub Actions: writes ``old=``, ``new=``, and
``changed=`` lines to ``$GITHUB_OUTPUT`` so a downstream step can gate PR
creation.
"""
from __future__ import annotations

import hashlib
import os
import pathlib
import re
import sys
import urllib.request

FILE = pathlib.Path("pkgs/claude-code-native/default.nix")
LATEST_URL = "https://downloads.claude.ai/claude-code-releases/latest"
BIN_URL = (
    "https://downloads.claude.ai/claude-code-releases/{version}/{platform}/claude"
)
PLATFORMS: dict[str, str] = {
    "aarch64-darwin": "darwin-arm64",
    "x86_64-darwin": "darwin-x64",
    "aarch64-linux": "linux-arm64",
    "x86_64-linux": "linux-x64",
}


def fetch(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=120) as r:
        return r.read()


def write_output(**kv: str) -> None:
    path = os.environ.get("GITHUB_OUTPUT")
    if not path:
        return
    with open(path, "a") as f:
        for k, v in kv.items():
            f.write(f"{k}={v}\n")


def main() -> int:
    src = FILE.read_text()
    current_match = re.search(r'version\s*=\s*"([^"]+)"', src)
    if not current_match:
        sys.exit("could not parse current version")
    current = current_match.group(1)

    latest = fetch(LATEST_URL).decode().strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+", latest):
        sys.exit(f"unexpected version string: {latest!r}")

    if current == latest:
        print(f"already-up-to-date: {current}")
        write_output(changed="false", old=current, new=latest)
        return 0

    print(f"bumping {current} -> {latest}")
    src = src.replace(
        f'version = "{current}"', f'version = "{latest}"', 1
    )

    for nix_sys, dl_sys in PLATFORMS.items():
        url = BIN_URL.format(version=latest, platform=dl_sys)
        h = hashlib.sha256(fetch(url)).hexdigest()
        print(f"  {nix_sys}: {h}")
        # Match within the per-platform attrset only — non-greedy up to the
        # first closing brace so we don't bleed across platforms.
        pattern = rf'({re.escape(nix_sys)}\s*=\s*\{{.*?sha256\s*=\s*")[^"]+(")'
        src, n = re.subn(
            pattern,
            lambda m, h=h: m.group(1) + h + m.group(2),
            src,
            count=1,
            flags=re.DOTALL,
        )
        if n != 1:
            sys.exit(f"failed to rewrite sha256 for {nix_sys}")

    FILE.write_text(src)
    write_output(changed="true", old=current, new=latest)
    return 0


if __name__ == "__main__":
    sys.exit(main())
