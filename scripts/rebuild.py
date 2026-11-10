"""Rebuild the Darwin configuration, optionally upgrading Homebrew packages."""

import argparse
import subprocess
import sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument(
        "--upgrade-brew", action="store_true",
        help="upgrade Homebrew packages after a successful rebuild",
    )
    options, darwin_arguments = parser.parse_known_args()
    root = Path(__file__).resolve().parents[1]
    subprocess.run(
        ["sudo", "darwin-rebuild", "switch", "--flake", str(root), *darwin_arguments],
        cwd=root, check=True,
    )
    if options.upgrade_brew:
        subprocess.run(["brew", "upgrade"], cwd=root, check=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, subprocess.CalledProcessError) as error:
        sys.exit(f"rebuild: {error}")
