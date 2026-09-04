"""Render automated dependency update details as GitHub-flavored Markdown."""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections.abc import Iterable
from typing import Any
from urllib.parse import quote

MARKDOWN_HEADING_PATTERN = re.compile(r"^(#{1,6})(\s+.*)$")
CLOSURE_SIZE_PATTERN = re.compile(r", [+-][0-9]+(?:\.[0-9]+)? [A-Za-z]+$")
MENTION_PATTERN = re.compile(r"(?<![A-Za-z0-9_])@(?=[A-Za-z0-9])")


class RenderError(ValueError):
    """Raised when update metadata cannot be rendered safely."""


def flatten_releases(payload: Any) -> list[dict[str, Any]]:
    if not isinstance(payload, list):
        raise RenderError("release payload must be a JSON array")

    flattened: list[dict[str, Any]] = []
    for item in payload:
        if isinstance(item, list):
            flattened.extend(flatten_releases(item))
        elif isinstance(item, dict):
            flattened.append(item)
        else:
            raise RenderError("release payload entries must be JSON objects")
    return flattened


def demote_headings(markdown: str) -> str:
    lines: list[str] = []
    for line in markdown.splitlines():
        match = MARKDOWN_HEADING_PATTERN.match(line)
        if match:
            level = min(len(match.group(1)) + 2, 6)
            line = f"{'#' * level}{match.group(2)}"
        lines.append(line)
    return "\n".join(lines)


def neutralize_mentions(markdown: str) -> str:
    return MENTION_PATTERN.sub("&#64;", markdown)


def render_releases(
    payload: Any,
    repository: str,
    tag_prefix: str,
    old_version: str,
    new_version: str,
) -> str:
    installed_tag = f"{tag_prefix}{old_version}"
    target_tag = f"{tag_prefix}{new_version}"
    matching_releases: list[dict[str, Any]] = []

    for release in flatten_releases(payload):
        tag = release.get("tag_name")
        if not isinstance(tag, str) or not tag.startswith(tag_prefix):
            continue
        matching_releases.append(release)

    release_tags = [str(release["tag_name"]) for release in matching_releases]
    if target_tag not in release_tags:
        raise RenderError(f"target release {target_tag} was not published")
    if installed_tag not in release_tags:
        raise RenderError(f"installed release {installed_tag} was not included")

    target_index = release_tags.index(target_tag)
    installed_index = release_tags.index(installed_tag)
    if target_index >= installed_index:
        raise RenderError(f"target release {target_tag} is not newer than {installed_tag}")

    selected = reversed(matching_releases[target_index:installed_index])

    sections: list[str] = []
    for release in selected:
        tag = str(release["tag_name"])
        version = tag.removeprefix(tag_prefix)
        url = release.get("html_url")
        if not isinstance(url, str) or not url:
            url = f"https://github.com/{repository}/releases/tag/{quote(tag, safe='')}"

        body = release.get("body")
        if not isinstance(body, str) or not body.strip():
            body = "_No release notes were published for this version._"
        else:
            body = neutralize_mentions(demote_headings(body.strip()))

        sections.append(f"## [{version}]({url})\n\n{body}")

    return "\n\n".join(sections) + "\n"


def closure_versions(value: str) -> list[str]:
    if value in {"", "∅", "ε"}:
        return []
    return value.split(", ")


def markdown_code(value: str) -> str:
    escaped = value.replace("|", "\\|").replace("`", "\\`")
    return f"`{escaped}`"


def versions_cell(versions: Iterable[str]) -> str:
    return ", ".join(markdown_code(version) for version in versions)


def render_table(title: str, headings: list[str], rows: list[list[str]]) -> str:
    lines = [f"### {title}", "", f"| {' | '.join(headings)} |"]
    lines.append(f"| {' | '.join('---' for _ in headings)} |")
    lines.extend(f"| {' | '.join(row)} |" for row in rows)
    return "\n".join(lines)


def render_closure(payload: str) -> str:
    updated: list[list[str]] = []
    added: list[list[str]] = []
    removed: list[list[str]] = []

    for line in sorted(payload.splitlines()):
        package, separator, change = line.partition(": ")
        if not separator or " → " not in change:
            continue

        before_text, after_text = change.split(" → ", maxsplit=1)
        after_text = CLOSURE_SIZE_PATTERN.sub("", after_text)
        before = closure_versions(before_text)
        after = closure_versions(after_text)
        if not before and not after:
            continue

        package_cell = markdown_code(package)
        if before and after:
            updated.append([package_cell, versions_cell(before), versions_cell(after)])
        elif after:
            added.append([package_cell, versions_cell(after)])
        else:
            removed.append([package_cell, versions_cell(before)])

    tables: list[str] = []
    if updated:
        tables.append(render_table("Updated packages", ["Package", "Before", "After"], updated))
    if added:
        tables.append(render_table("Added packages", ["Package", "Version"], added))
    if removed:
        tables.append(render_table("Removed packages", ["Package", "Version"], removed))
    if not tables:
        return "_No versioned package changes._\n"
    return "\n\n".join(tables) + "\n"


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)

    releases = subparsers.add_parser("releases")
    releases.add_argument("--repository", required=True)
    releases.add_argument("--tag-prefix", required=True)
    releases.add_argument("--old-version", required=True)
    releases.add_argument("--new-version", required=True)

    subparsers.add_parser("closure")
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    try:
        payload = sys.stdin.read()
        if arguments.command == "releases":
            output = render_releases(
                json.loads(payload),
                arguments.repository,
                arguments.tag_prefix,
                arguments.old_version,
                arguments.new_version,
            )
        else:
            output = render_closure(payload)
    except (json.JSONDecodeError, RenderError) as error:
        print(f"Error: {error}", file=sys.stderr)
        return 1

    sys.stdout.write(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
