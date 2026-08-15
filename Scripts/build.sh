#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export PKG_CONFIG_PATH="/opt/homebrew/opt/libarchive/lib/pkgconfig:/usr/local/opt/libarchive/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

CONFIGURATION="${1:-debug}"
if [[ "$CONFIGURATION" == "release" ]]; then
  swift build -c release --product archivemgr
  swift build -c release --product ArchivistApp
else
  swift build --product archivemgr --product ArchivistApp
fi

echo "Build OK ($CONFIGURATION)"
