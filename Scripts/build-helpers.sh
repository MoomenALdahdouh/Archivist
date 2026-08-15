#!/bin/zsh
set -euo pipefail
# Downloads official RARLAB helpers and optional 7-Zip.
# UnRAR may be redistributed. The `rar` compressor is RARLAB's official
# command-line tool, invoked as a separate process — Archivist does not
# reimplement RAR compression.

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

RAR_VERSION="${ARCHIVIST_RAR_VERSION:-723}"
ARCH="$(uname -m)"
if [[ "$ARCH" == "arm64" ]]; then
  RAR_URL="https://www.rarlab.com/rar/rarmacos-arm-${RAR_VERSION}.tar.gz"
else
  RAR_URL="https://www.rarlab.com/rar/rarmacos-x64-${RAR_VERSION}.tar.gz"
fi

echo "Downloading RARLAB helpers from $RAR_URL"
curl -fsSL "$RAR_URL" -o "$SRC/rarmacos.tar.gz"
rm -rf "$SRC/rar"
tar -xzf "$SRC/rarmacos.tar.gz" -C "$SRC"

if [[ -x "$SRC/rar/unrar" ]]; then
  cp "$SRC/rar/unrar" "$BUILD/ArchivistUnrar"
  chmod +x "$BUILD/ArchivistUnrar"
  echo "Installed ArchivistUnrar"
elif command -v unrar >/dev/null 2>&1; then
  cp "$(command -v unrar)" "$BUILD/ArchivistUnrar"
  echo "Copied system unrar -> ArchivistUnrar"
else
  echo "unrar not found. RAR extraction will fall back to libarchive/7-Zip." >&2
fi

if [[ -x "$SRC/rar/rar" ]]; then
  cp "$SRC/rar/rar" "$BUILD/ArchivistRar"
  chmod +x "$BUILD/ArchivistRar"
  echo "Installed ArchivistRar"
elif command -v rar >/dev/null 2>&1; then
  cp "$(command -v rar)" "$BUILD/ArchivistRar"
  echo "Copied system rar -> ArchivistRar"
else
  echo "rar not found. RAR creation will be unavailable." >&2
fi

if [[ -f "$SRC/rar/rarfiles.lst" ]]; then
  cp "$SRC/rar/rarfiles.lst" "$BUILD/rarfiles.lst"
fi
if [[ -f "$SRC/rar/default.sfx" ]]; then
  cp "$SRC/rar/default.sfx" "$BUILD/default.sfx"
fi
if [[ -f "$SRC/rar/license.txt" ]]; then
  cp "$SRC/rar/license.txt" "$BUILD/RARLAB-license.txt"
fi

echo "Helpers ready in $BUILD"
ls -l "$BUILD"
