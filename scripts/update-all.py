"""Refresh local packages and flake inputs, then activate the Darwin configuration."""

import re
import subprocess
import sys
from pathlib import Path

# shortcut: only numeric GitHub release tags are bumped; extend when another tag scheme is used.
RELEASE_URL = re.compile(
    r'(?P<assignment>\burl\s*=\s*")github:(?P<repository>[\w.-]+/[\w.-]+)/(?P<tag>v?\d+(?:\.\d+)+)(?=")'
)


def run(*command, cwd):
    print(f"==> {' '.join(map(str, command))}", flush=True)
    subprocess.run(command, cwd=cwd, check=True)


def update_release_pins(flake):
    before = flake.read_text()

    def latest_release(match):
        repository, old_tag = match["repository"], match["tag"]
        tag = subprocess.check_output(
            [
                "gh", "release", "view", "--repo", repository,
                "--json", "tagName", "--jq", ".tagName",
            ],
            cwd=flake.parent,
            text=True,
        ).strip()
        if not re.fullmatch(r"v?\d+(?:\.\d+)+", tag):
            raise ValueError(f"Unexpected release tag for {repository}: {tag!r}")
        old_version = tuple(map(int, old_tag.lstrip("v").split(".")))
        new_version = tuple(map(int, tag.lstrip("v").split(".")))
        if new_version <= old_version:
            return match[0]
        print(f"==> {repository}: {old_tag} -> {tag}", flush=True)
        return f'{match["assignment"]}github:{repository}/{tag}'

    after = RELEASE_URL.sub(latest_release, before)
    if after != before:
        flake.write_text(after)


def main():
    root = Path(__file__).resolve().parents[1]
    packages = root / "pkgs"
    for updater in sorted(packages.rglob("update.sh")):
        run("bash", str(updater), cwd=updater.parent)
    for flake in [*sorted(packages.rglob("flake.nix")), root / "flake.nix"]:
        update_release_pins(flake)
        run("nix", "flake", "update", "--flake", str(flake.parent), cwd=flake.parent)
    run("sudo", "darwin-rebuild", "switch", "--flake", str(root), cwd=root)


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        sys.exit(f"update-all: {error}")
