#!/usr/bin/env bash
# Update Codex to a specific version, or to the latest GitHub release.
# Usage: ./update.sh [version]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="$SCRIPT_DIR/default.nix"
VERSION="${1:-}"

command -v gh >/dev/null || {
  echo "Error: 'gh' CLI not available. Install it to fetch release metadata." >&2
  exit 1
}

if [[ -z "$VERSION" ]]; then
  RELEASE=$(gh api repos/openai/codex/releases/latest)
else
  VERSION="${VERSION#rust-v}"
  VERSION="${VERSION#v}"
  RELEASE=$(gh api "repos/openai/codex/releases/tags/rust-v$VERSION")
fi

TAG=$(jq -er '.tag_name' <<< "$RELEASE")
if [[ ! "$TAG" =~ ^rust-v[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
  echo "Error: unexpected Codex release tag: $TAG" >&2
  exit 1
fi
VERSION="${TAG#rust-v}"

TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

declare -A ASSETS=(
  [aarch64-darwin]="codex-package-aarch64-apple-darwin.tar.gz"
  [x86_64-darwin]="codex-package-x86_64-apple-darwin.tar.gz"
  [aarch64-linux]="codex-package-aarch64-unknown-linux-musl.tar.gz"
  [x86_64-linux]="codex-package-x86_64-unknown-linux-musl.tar.gz"
)
declare -A CHECKSUMS

echo "Reading published checksums for Codex $VERSION..."
for platform in "${!ASSETS[@]}"; do
  asset="${ASSETS[$platform]}"
  digest=$(jq -er --arg name "$asset" '.assets[] | select(.name == $name) | .digest' <<< "$RELEASE") || {
    echo "Error: missing SHA-256 digest for $asset" >&2
    exit 1
  }
  if [[ ! "$digest" =~ ^sha256:[[:xdigit:]]{64}$ ]]; then
    echo "Error: invalid SHA-256 digest for $asset" >&2
    exit 1
  fi
  CHECKSUMS[$platform]="${digest#sha256:}"
  echo "  $platform: ${CHECKSUMS[$platform]}"
done

awk \
  -v version="$VERSION" \
  -v aarch64_darwin="${CHECKSUMS[aarch64-darwin]}" \
  -v x86_64_darwin="${CHECKSUMS[x86_64-darwin]}" \
  -v aarch64_linux="${CHECKSUMS[aarch64-linux]}" \
  -v x86_64_linux="${CHECKSUMS[x86_64-linux]}" '
  /^  version = / { print "  version = \"" version "\";"; next }
  /aarch64-darwin =/ { platform = "aarch64_darwin" }
  /x86_64-darwin =/  { platform = "x86_64_darwin" }
  /aarch64-linux =/  { platform = "aarch64_linux" }
  /x86_64-linux =/   { platform = "x86_64_linux" }
  /sha256 = / && platform != "" {
    checksum = platform == "aarch64_darwin" ? aarch64_darwin :
      platform == "x86_64_darwin" ? x86_64_darwin :
      platform == "aarch64_linux" ? aarch64_linux : x86_64_linux
    sub(/sha256 = "[^"]*"/, "sha256 = \"" checksum "\"")
    platform = ""
  }
  { print }
' "$DEFAULT_NIX" > "$TMP_DIR/default.nix"

mv "$TMP_DIR/default.nix" "$DEFAULT_NIX"
echo "Updated $DEFAULT_NIX to version $VERSION"
