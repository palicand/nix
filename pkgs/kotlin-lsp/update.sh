#!/usr/bin/env bash
# Update kotlin-lsp to a specific version, or to the latest GitHub release.
# Usage: ./update.sh [version]
# Examples:
#   ./update.sh              # fetch latest release from GitHub
#   ./update.sh 262.4739.0
#   ./update.sh v262.4739.0  # tag-style accepted

set -euo pipefail

VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
  echo "No version specified; querying GitHub for the latest release..."
  if ! command -v gh >/dev/null; then
    echo "Error: 'gh' CLI not available. Install it or pass a version explicitly."
    echo "Latest releases: https://github.com/Kotlin/kotlin-lsp/releases"
    exit 1
  fi
  TAG=$(gh release list --repo Kotlin/kotlin-lsp --limit 1 --json tagName -q '.[0].tagName') || {
    echo "Error: failed to query GitHub releases for Kotlin/kotlin-lsp."
    exit 1
  }
  # Tags look like "kotlin-lsp/v262.4739.0"; strip the project prefix.
  VERSION="${TAG#kotlin-lsp/}"
  echo "Latest release: $TAG"
fi

# Accept tag-style versions (e.g. v262.4739.0); the CDN path has no 'v' prefix.
VERSION="${VERSION#v}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_NIX="$SCRIPT_DIR/default.nix"
BASE_URL="https://download-cdn.jetbrains.com/kotlin-lsp/${VERSION}"

echo "Fetching checksums for version $VERSION..."

# Each platform has its own archive suffix. JetBrains migrated kotlin-lsp's
# standalone artifacts from `kotlin-lsp-<ver>-<plat>.zip` to per-platform
# native archives: `.sit` (a zip with macOS metadata) on Darwin and `.tar.gz`
# on Linux. x86_64 has no platform suffix in the filename.
declare -A PLATFORMS=(
  ["aarch64-darwin"]="-aarch64.sit"
  ["x86_64-darwin"]=".sit"
  ["aarch64-linux"]="-aarch64.tar.gz"
  ["x86_64-linux"]=".tar.gz"
)

declare -A CHECKSUMS

for nix_platform in "${!PLATFORMS[@]}"; do
  suffix="${PLATFORMS[$nix_platform]}"
  url="${BASE_URL}/kotlin-server-${VERSION}${suffix}.sha256"

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
