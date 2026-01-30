#!/usr/bin/env bash
# Update kotlin-lsp to a specific version
# Usage: ./update.sh <version>
# Example: ./update.sh 261.13587.0

set -euo pipefail

VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version>"
  echo "Example: $0 261.13587.0"
  echo ""
  echo "To find the latest version, check:"
  echo "  https://github.com/Kotlin/kotlin-lsp/releases"
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="$SCRIPT_DIR/default.nix"
BASE_URL="https://download-cdn.jetbrains.com/kotlin-lsp/${VERSION}"

echo "Fetching checksums for version $VERSION..."

# Platforms to fetch
declare -A PLATFORMS=(
  ["aarch64-darwin"]="mac-aarch64"
  ["x86_64-darwin"]="mac-x64"
  ["aarch64-linux"]="linux-aarch64"
  ["x86_64-linux"]="linux-x64"
)

declare -A CHECKSUMS

for nix_platform in "${!PLATFORMS[@]}"; do
  jetbrains_platform="${PLATFORMS[$nix_platform]}"
  url="${BASE_URL}/kotlin-lsp-${VERSION}-${jetbrains_platform}.zip.sha256"

  checksum=$(curl -sf "$url" | awk '{print $1}') || {
    echo "Error: Failed to fetch checksum for $nix_platform"
    echo "URL: $url"
    exit 1
  }

  CHECKSUMS[$nix_platform]="$checksum"
  echo "  $nix_platform: $checksum"
done

echo ""
echo "Updating $DEFAULT_NIX..."

# Read the file and make replacements
CONTENT=$(<"$DEFAULT_NIX")

# Update version
CONTENT=$(echo "$CONTENT" | awk -v ver="$VERSION" '
  /^  version = / { print "  version = \"" ver "\";"; next }
  { print }
')

# Update checksums
CONTENT=$(echo "$CONTENT" | awk \
  -v darwin_arm64="${CHECKSUMS[aarch64-darwin]}" \
  -v darwin_x64="${CHECKSUMS[x86_64-darwin]}" \
  -v linux_arm64="${CHECKSUMS[aarch64-linux]}" \
  -v linux_x64="${CHECKSUMS[x86_64-linux]}" '
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
echo "  3. Commit: git add -A && git commit -m 'Update kotlin-lsp to $VERSION'"
echo "  4. Rebuild system: rebuild"
