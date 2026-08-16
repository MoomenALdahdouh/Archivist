#!/bin/zsh
set -euo pipefail
# Build Archivist from source and install it to /Applications.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required to build from source." >&2
  echo "Install it from https://brew.sh then run this script again." >&2
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "The Swift toolchain is required. Install Xcode or Apple's Command Line Tools." >&2
  exit 1
fi

echo "Installing build dependencies…"
brew install libarchive xz zstd lz4 libb2 sevenzip pkg-config

export PKG_CONFIG_PATH="$(brew --prefix libarchive)/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

"$ROOT/Scripts/build-helpers.sh"
ARCHIVIST_INSTALL_FINDER=1 "$ROOT/Scripts/package-app.sh"

echo
echo "Archivist is in /Applications."
echo "The first time macOS asks, right-click the app and choose Open."
echo "Then right-click files in Finder and look under Quick Actions or Services."
