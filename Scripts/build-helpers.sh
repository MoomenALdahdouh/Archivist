#!/bin/zsh
set -euo pipefail
# Downloads and builds optional 7-Zip and UnRAR helpers.
# 7-Zip: LGPL helper process. UnRAR: extract-only, required license paragraph is in THIRD_PARTY_LICENSES.md.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Helpers/src"
BUILD="$ROOT/Helpers/build"
mkdir -p "$SRC" "$BUILD"

echo "Building helpers into $BUILD"

if command -v 7zz >/dev/null 2>&1; then
  cp "$(command -v 7zz)" "$BUILD/Archivist7z"
  echo "Copied system 7zz -> Archivist7z"
elif [[ -x /opt/homebrew/bin/7zz ]]; then
  cp /opt/homebrew/bin/7zz "$BUILD/Archivist7z"
else
  echo "7zz not found. Install with: brew install sevenzip"
  echo "Encrypted 7Z / WIM / MSI will be unavailable until the helper exists."
fi

if command -v unrar >/dev/null 2>&1; then
  cp "$(command -v unrar)" "$BUILD/ArchivistUnrar"
  echo "Copied system unrar -> ArchivistUnrar"
else
  echo "unrar not found. Encrypted RAR extraction requires UnRAR."
  echo "libarchive can still list/extract some unencrypted RAR archives."
fi
