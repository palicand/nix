import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]


class UpdateAllTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = (Path(self.temporary.name) / "config with spaces").resolve()
        (self.root / "scripts").mkdir(parents=True)
        self.script = self.root / "scripts" / "update-all.py"
        shutil.copyfile(REPOSITORY_ROOT / "scripts" / "update-all.py", self.script)
        self.flake = self.root / "flake.nix"
        self.flake.write_text('''{
  inputs.brew-src.url = "github:Homebrew/brew/7.0.11";
  inputs.herdr.url = "github:herdrdev/herdr/v0.9.5";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.fixed.url = "github:example/fixed/0123456789abcdef";
}
''')
        self.log = self.root / "commands.jsonl"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        stub = self.bin / "command-stub"
        stub.write_text(f'''#!{sys.executable}
import json
import os
import sys
from pathlib import Path
name = Path(sys.argv[0]).name
with open(os.environ["UPDATE_LOG"], "a") as log:
    log.write(json.dumps([name, *sys.argv[1:]]) + "\\n")
if os.environ.get("FAIL_COMMAND") == name:
    sys.exit(1)
if name == "gh":
    print(os.environ.get("LATEST_TAG", {{
        "Homebrew/brew": "7.0.12",
        "herdrdev/herdr": "v0.9.6",
        "example/future": "v2.0.0",
    }}[sys.argv[sys.argv.index("--repo") + 1]]))
''')
        stub.chmod(0o755)
        for command in ("nix", "gh", "sudo"):
            (self.bin / command).symlink_to(stub)

    def package(self, name, *, flake=True, updater=True, fails=False):
        directory = self.root / "pkgs" / name
        directory.mkdir(parents=True)
        if flake:
            (directory / "flake.nix").write_text("{}\n")
        if updater:
            (directory / "update.sh").write_text(
                'set -eu\n'
                f'printf \'["package", "{name}"]\\n\' >> "$UPDATE_LOG"\n'
                'test "$PWD" = "$(cd "$(dirname "$0")" && pwd)"\n'
                f"exit {1 if fails else 0}\n"
            )

    def run_update(self, **environment):
        result = subprocess.run(
            [sys.executable, str(self.script)],
            cwd=self.temporary.name,
            env={
                **os.environ,
                "PATH": f"{self.bin}:{os.environ['PATH']}",
                "UPDATE_LOG": str(self.log),
                **environment,
            },
            capture_output=True,
            text=True,
        )
        calls = (
            [json.loads(line) for line in self.log.read_text().splitlines()]
            if self.log.exists() else []
        )
        return result, calls

    def test_discovers_packages_flakes_and_new_release_inputs(self):
        self.package("claude-code-native")
        self.package("future/package with spaces")
        self.package("only-updater", flake=False)
        self.package("only-flake", updater=False)
        future = self.root / "pkgs/future/package with spaces/flake.nix"
        future.write_text('{ inputs.new.url = "github:example/future/v1.0.0"; }\n')

        result, calls = self.run_update()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([call for call in calls if call[0] == "package"], [
            ["package", "claude-code-native"],
            ["package", "future/package with spaces"],
            ["package", "only-updater"],
        ])
        self.assertEqual([call for call in calls if call[0] == "nix"], [
            ["nix", "flake", "update", "--flake", str(self.root / "pkgs/claude-code-native")],
            ["nix", "flake", "update", "--flake", str(future.parent)],
            ["nix", "flake", "update", "--flake", str(self.root / "pkgs/only-flake")],
            ["nix", "flake", "update", "--flake", str(self.root)],
        ])
        self.assertIn("github:Homebrew/brew/7.0.12", self.flake.read_text())
        self.assertIn("github:herdrdev/herdr/v0.9.6", self.flake.read_text())
        self.assertIn("github:NixOS/nixpkgs/nixpkgs-unstable", self.flake.read_text())
        self.assertIn("github:example/fixed/0123456789abcdef", self.flake.read_text())
        self.assertIn("github:example/future/v2.0.0", future.read_text())
        self.assertEqual(calls[-1], ["sudo", "darwin-rebuild", "switch", "--flake", str(self.root)])

    def test_package_failure_prevents_rebuild(self):
        self.package("broken", fails=True)
        result, calls = self.run_update()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, [["package", "broken"]])

    def test_flake_failure_prevents_rebuild(self):
        result, calls = self.run_update(FAIL_COMMAND="nix")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls[-1][0], "nix")
        self.assertFalse(any(call[0] == "sudo" for call in calls))

    def test_release_lookup_failure_leaves_pins_unchanged(self):
        before = self.flake.read_text()
        result, calls = self.run_update(FAIL_COMMAND="gh")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.flake.read_text(), before)
        self.assertEqual(calls[0][0], "gh")
        self.assertFalse(any(call[0] in ("nix", "sudo") for call in calls))

    def test_invalid_release_tag_cannot_inject_nix(self):
        before = self.flake.read_text()
        result, calls = self.run_update(LATEST_TAG='7.0.12"; malicious = "yes')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.flake.read_text(), before)
        self.assertEqual(calls[0][0], "gh")
        self.assertFalse(any(call[0] == "sudo" for call in calls))

    def test_older_stable_release_does_not_downgrade_a_pin(self):
        self.flake.write_text('{ inputs.brew-src.url = "github:Homebrew/brew/7.0.11"; }\n')
        before = self.flake.read_text()
        result, _ = self.run_update(LATEST_TAG="7.0.10")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.flake.read_text(), before)

    def test_only_updates_input_urls(self):
        self.flake.write_text('''{
  inputs.brew-src.url = "github:Homebrew/brew/7.0.11";
  description = "github:Homebrew/brew/7.0.11";
}
''')
        result, _ = self.run_update()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('url = "github:Homebrew/brew/7.0.12"', self.flake.read_text())
        self.assertIn('description = "github:Homebrew/brew/7.0.11"', self.flake.read_text())


if __name__ == "__main__":
    unittest.main()
