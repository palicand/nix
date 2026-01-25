#!/usr/bin/env bash
# Update claude-code-native to a specific version
# Usage: ./update.sh <version>
# Example: ./update.sh 2.1.20

set -euo pipefail

VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version>"
  echo "Example: $0 2.1.20"
  echo ""
  echo "To find the latest version, check:"
  echo "  https://code.claude.com/docs/en/setup"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="$SCRIPT_DIR/default.nix"
BASE_URL="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"
MANIFEST_URL="$BASE_URL/$VERSION/manifest.json"

echo "Fetching manifest for version $VERSION..."
MANIFEST=$(curl -sf "$MANIFEST_URL") || {
  echo "Error: Failed to fetch manifest. Version $VERSION may not exist."
  echo "URL: $MANIFEST_URL"
  exit 1
}

echo "Extracting checksums..."

# Extract checksums from manifest using jq
# The manifest has format: { "platforms": { "darwin-arm64": { "checksum": "..." }, ... } }
DARWIN_ARM64=$(echo "$MANIFEST" | jq -r '.platforms["darwin-arm64"].checksum')
DARWIN_X64=$(echo "$MANIFEST" | jq -r '.platforms["darwin-x64"].checksum')
LINUX_ARM64=$(echo "$MANIFEST" | jq -r '.platforms["linux-arm64"].checksum')
LINUX_X64=$(echo "$MANIFEST" | jq -r '.platforms["linux-x64"].checksum')

if [[ "$DARWIN_ARM64" == "null" ]] || [[ -z "$DARWIN_ARM64" ]]; then
  echo "Error: Could not extract checksums from manifest"
  echo "Manifest content:"
  echo "$MANIFEST" | jq .
  exit 1
fi

echo ""
echo "Version: $VERSION"
echo "Checksums:"
echo "  darwin-arm64: $DARWIN_ARM64"
echo "  darwin-x64:   $DARWIN_X64"
echo "  linux-arm64:  $LINUX_ARM64"
echo "  linux-x64:    $LINUX_X64"
echo ""

echo "Updating $DEFAULT_NIX..."

# Read the file, make replacements, write back
# This approach is portable across macOS and Linux
CONTENT=$(<"$DEFAULT_NIX")

# Update version (line 9)
CONTENT=$(echo "$CONTENT" | awk -v ver="$VERSION" '
  /^  version = / { print "  version = \"" ver "\";"; next }
  { print }
')

# Update checksums - each sha256 appears right after its platform block
# Use awk to do targeted replacement based on preceding lines
CONTENT=$(echo "$CONTENT" | awk -v darwin_arm64="$DARWIN_ARM64" \
                                -v darwin_x64="$DARWIN_X64" \
                                -v linux_arm64="$LINUX_ARM64" \
                                -v linux_x64="$LINUX_X64" '
  /aarch64-darwin/ { in_darwin_arm64 = 1 }
  /x86_64-darwin/  { in_darwin_arm64 = 0; in_darwin_x64 = 1 }
  /aarch64-linux/  { in_darwin_x64 = 0; in_linux_arm64 = 1 }
  /x86_64-linux/   { in_linux_arm64 = 0; in_linux_x64 = 1 }
  /^\s*\};/        { in_linux_x64 = 0 }

  /sha256 = / && in_darwin_arm64 { gsub(/sha256 = "[^"]*"/, "sha256 = \"" darwin_arm64 "\"") }
  /sha256 = / && in_darwin_x64   { gsub(/sha256 = "[^"]*"/, "sha256 = \"" darwin_x64 "\"") }
  /sha256 = / && in_linux_arm64  { gsub(/sha256 = "[^"]*"/, "sha256 = \"" linux_arm64 "\"") }
  /sha256 = / && in_linux_x64    { gsub(/sha256 = "[^"]*"/, "sha256 = \"" linux_x64 "\"") }

  { print }
')

echo "$CONTENT" > "$DEFAULT_NIX"

echo "Updated $DEFAULT_NIX to version $VERSION"
echo ""
echo "Next steps:"
echo "  1. Review changes: git diff $DEFAULT_NIX"
echo "  2. Test build: nix build"
echo "  3. Commit: git add -A && git commit -m 'Update claude-code-native to $VERSION'"
echo "  4. Rebuild system: rebuild"
