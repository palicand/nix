import json
import subprocess
import sys
import unittest
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[1]
RENDERER = REPOSITORY_ROOT / "scripts" / "render-updates.py"


def run_renderer(
    *arguments: str,
    payload: object | None = None,
    input_text: str | None = None,
) -> subprocess.CompletedProcess[str]:
    if (payload is None) == (input_text is None):
        raise ValueError("provide exactly one of payload or input_text")
    return subprocess.run(
        [sys.executable, str(RENDERER), *arguments],
        input=json.dumps(payload) if payload is not None else input_text,
        text=True,
        capture_output=True,
        check=False,
    )


class ReleaseNotesTests(unittest.TestCase):
    def test_renders_every_release_in_upgrade_range_as_its_own_section(self) -> None:
        releases = [
            [
                {
                    "tag_name": "rust-v0.153.0",
                    "html_url": "https://github.com/openai/codex/releases/tag/rust-v0.153.0",
                    "body": "## Fixes\n\n- Fixed the newest issue.",
                },
                {
                    "tag_name": "rust-v0.152.0",
                    "html_url": "https://github.com/openai/codex/releases/tag/rust-v0.152.0",
                    "body": "",
                },
            ],
            [
                {
                    "tag_name": "rust-v0.151.0",
                    "html_url": "https://github.com/openai/codex/releases/tag/rust-v0.151.0",
                    "body": "# Features\n\n- Added the older feature. @upstream-author",
                },
                {
                    "tag_name": "rust-v0.150.0",
                    "html_url": "https://github.com/openai/codex/releases/tag/rust-v0.150.0",
                    "body": "- Already installed.",
                },
            ],
        ]

        result = run_renderer(
            "releases",
            "--repository",
            "openai/codex",
            "--tag-prefix",
            "rust-v",
            "--old-version",
            "0.150.0",
            "--new-version",
            "0.153.0",
            payload=releases,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout,
            """## [0.151.0](https://github.com/openai/codex/releases/tag/rust-v0.151.0)

### Features

- Added the older feature. &#64;upstream-author

## [0.152.0](https://github.com/openai/codex/releases/tag/rust-v0.152.0)

_No release notes were published for this version._

## [0.153.0](https://github.com/openai/codex/releases/tag/rust-v0.153.0)

#### Fixes

- Fixed the newest issue.
""",
        )

    def test_fails_when_target_release_is_not_published(self) -> None:
        releases = [
            {
                "tag_name": "v2.1.258",
                "html_url": "https://github.com/anthropics/claude-code/releases/tag/v2.1.258",
                "body": "- Previous release.",
            }
        ]

        result = run_renderer(
            "releases",
            "--repository",
            "anthropics/claude-code",
            "--tag-prefix",
            "v",
            "--old-version",
            "2.1.257",
            "--new-version",
            "2.1.259",
            payload=releases,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("target release v2.1.259 was not published", result.stderr)

    def test_fails_when_installed_release_boundary_is_missing(self) -> None:
        releases = [
            {
                "tag_name": "v2.1.259",
                "html_url": "https://github.com/anthropics/claude-code/releases/tag/v2.1.259",
                "body": "- Target release.",
            },
            {
                "tag_name": "v2.1.258",
                "html_url": "https://github.com/anthropics/claude-code/releases/tag/v2.1.258",
                "body": "- Intermediate release.",
            },
        ]

        result = run_renderer(
            "releases",
            "--repository",
            "anthropics/claude-code",
            "--tag-prefix",
            "v",
            "--old-version",
            "2.1.257",
            "--new-version",
            "2.1.259",
            payload=releases,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("installed release v2.1.257 was not included", result.stderr)

    def test_supports_nonnumeric_versions_in_github_release_order(self) -> None:
        releases = [
            [
                {
                    "tag_name": "release-2026.09-stable",
                    "html_url": "https://github.com/example/tool/releases/tag/release-2026.09-stable",
                    "body": "- Stable release.",
                },
                {
                    "tag_name": "release-2026.09-beta",
                    "html_url": "https://github.com/example/tool/releases/tag/release-2026.09-beta",
                    "body": "- Beta release.",
                },
            ],
            [
                {
                    "tag_name": "release-2026.08",
                    "html_url": "https://github.com/example/tool/releases/tag/release-2026.08",
                    "body": "- Already installed.",
                }
            ],
        ]

        result = run_renderer(
            "releases",
            "--repository",
            "example/tool",
            "--tag-prefix",
            "release-",
            "--old-version",
            "2026.08",
            "--new-version",
            "2026.09-stable",
            payload=releases,
        )

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout,
            """## [2026.09-beta](https://github.com/example/tool/releases/tag/release-2026.09-beta)

- Beta release.

## [2026.09-stable](https://github.com/example/tool/releases/tag/release-2026.09-stable)

- Stable release.
""",
        )


class ClosureDiffTests(unittest.TestCase):
    def test_groups_versioned_package_changes_and_omits_versionless_noise(self) -> None:
        closure_diff = """generated-config: +512.0 KiB
git: 2.50.1 → 2.51.0, +1.0 KiB
new-tool: ∅ → 1.0.0, +2.0 KiB
old-tool: 3.0.0 → ∅, -4.0 KiB
versionless: ε → ε, +1.0 KiB
"""

        result = run_renderer("closure", input_text=closure_diff)

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            result.stdout,
            """### Updated packages

| Package | Before | After |
| --- | --- | --- |
| `git` | `2.50.1` | `2.51.0` |

### Added packages

| Package | Version |
| --- | --- |
| `new-tool` | `1.0.0` |

### Removed packages

| Package | Version |
| --- | --- |
| `old-tool` | `3.0.0` |
""",
        )


if __name__ == "__main__":
    unittest.main()
