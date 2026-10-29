import copy
import json
import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
ASSETS = {
    "aarch64-darwin": "codex-package-aarch64-apple-darwin.tar.gz",
    "x86_64-darwin": "codex-package-x86_64-apple-darwin.tar.gz",
    "aarch64-linux": "codex-package-aarch64-unknown-linux-musl.tar.gz",
    "x86_64-linux": "codex-package-x86_64-unknown-linux-musl.tar.gz",
}


class CodexUpdateTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.script = self.root / "update.sh"
        self.package = self.root / "default.nix"
        shutil.copyfile(REPOSITORY_ROOT / "pkgs/codex/update.sh", self.script)
        self.before = (REPOSITORY_ROOT / "pkgs/codex/default.nix").read_text()
        self.hashes = {platform: str(index) * 64 for index, platform in enumerate(ASSETS, 1)}
        self.release = {
            "tag_name": "rust-v0.999.0",
            "assets": [
                {"name": asset, "digest": f"sha256:{self.hashes[platform]}"}
                for platform, asset in ASSETS.items()
            ] + [{"name": "codex-package-aarch64-apple-darwin.tar.zst", "digest": "sha256:" + "f" * 64}],
        }
        self.bin = self.root / "bin"
        self.bin.mkdir()
        stub = self.bin / "command-stub"
        stub.write_text('''#!/bin/sh
name=${0##*/}
printf '%s %s\\n' "$name" "$*" >> "$COMMAND_LOG"
if [ "$name" != gh ]; then
  echo "Unexpected binary download or hashing" >&2
  exit 99
fi
cat "$RELEASE_FIXTURE"
exit "${GH_EXIT:-0}"
''')
        stub.chmod(0o755)
        for command in ("gh", "curl", "shasum"):
            (self.bin / command).symlink_to(stub)
        self.fixture = self.root / "release.json"
        self.log = self.root / "commands.log"

    def run_update(self, *arguments, release=None, **environment):
        self.package.write_text(self.before)
        self.fixture.write_text(json.dumps(self.release if release is None else release))
        self.log.write_text("")
        result = subprocess.run(
            ["bash", str(self.script), *arguments],
            env={
                **os.environ,
                "PATH": f"{self.bin}:{os.environ['PATH']}",
                "RELEASE_FIXTURE": str(self.fixture),
                "COMMAND_LOG": str(self.log),
                **environment,
            },
            text=True,
            capture_output=True,
        )
        self.assertFalse(any(
            line.startswith(("curl ", "shasum "))
            for line in self.log.read_text().splitlines()
        ), self.log.read_text())
        return result

    def assert_updated(self, result, endpoint):
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text().splitlines(), [f"gh api repos/openai/codex/releases/{endpoint}"])
        actual = self.package.read_text()
        self.assertIn('version = "0.999.0";', actual)
        for platform, checksum in self.hashes.items():
            self.assertIn(f'{platform} = {{\n      url = "${{baseUrl}}/{ASSETS[platform]}";\n      sha256 = "{checksum}";', actual)

    def test_latest_release_uses_published_digests_without_downloading(self):
        self.assert_updated(self.run_update(), "latest")

    def test_explicit_version_formats_use_the_requested_release(self):
        for version in ("0.999.0", "v0.999.0", "rust-v0.999.0"):
            with self.subTest(version=version):
                self.assert_updated(self.run_update(version), "tags/rust-v0.999.0")

    def test_missing_or_invalid_digest_leaves_package_unchanged(self):
        for digest in (None, "", "sha256:1234", "sha512:" + "1" * 64, "sha256:" + "z" * 64):
            with self.subTest(digest=digest):
                release = copy.deepcopy(self.release)
                release["assets"][2]["digest"] = digest
                result = self.run_update(release=release)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(self.package.read_text(), self.before)

    def test_missing_asset_leaves_package_unchanged(self):
        release = copy.deepcopy(self.release)
        del release["assets"][0]
        result = self.run_update(release=release)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.package.read_text(), self.before)

    def test_api_failure_leaves_package_unchanged(self):
        result = self.run_update(GH_EXIT="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.package.read_text(), self.before)

    def test_invalid_release_tag_leaves_package_unchanged(self):
        release = copy.deepcopy(self.release)
        release["tag_name"] = 'rust-v0.999.0"; malicious = "yes'
        result = self.run_update(release=release)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.package.read_text(), self.before)


if __name__ == "__main__":
    unittest.main()
