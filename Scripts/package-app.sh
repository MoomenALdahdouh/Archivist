#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export PKG_CONFIG_PATH="/opt/homebrew/opt/libarchive/lib/pkgconfig:/usr/local/opt/libarchive/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

swift build -c release --product ArchivistApp
swift build -c release --product archivemgr

if [[ ! -x "$ROOT/Helpers/build/ArchivistRar" || ! -x "$ROOT/Helpers/build/ArchivistUnrar" ]]; then
  "$ROOT/Scripts/build-helpers.sh"
fi

BIN_APP="$(swift build -c release --show-bin-path)/ArchivistApp"
BIN_CLI="$(swift build -c release --show-bin-path)/archivemgr"
DIST="$ROOT/dist/Archivist.app"
rm -rf "$ROOT/dist"
mkdir -p "$DIST/Contents/MacOS" "$DIST/Contents/Helpers" "$DIST/Contents/Resources" "$DIST/Contents/Library/Services"

cp "$BIN_APP" "$DIST/Contents/MacOS/Archivist"
cp "$BIN_CLI" "$DIST/Contents/MacOS/archivemgr"
cp "$ROOT/Resources/Info.plist" "$DIST/Contents/Info.plist"
cp "$ROOT/Resources/Archivist.entitlements" "$DIST/Contents/Resources/"
cp "$ROOT/LICENSE" "$DIST/Contents/Resources/LICENSE"
cp "$ROOT/THIRD_PARTY_LICENSES.md" "$DIST/Contents/Resources/"

if [[ -x "$ROOT/Helpers/build/Archivist7z" ]]; then
  cp "$ROOT/Helpers/build/Archivist7z" "$DIST/Contents/Helpers/Archivist7z"
fi
if [[ -x "$ROOT/Helpers/build/ArchivistUnrar" ]]; then
  cp "$ROOT/Helpers/build/ArchivistUnrar" "$DIST/Contents/Helpers/ArchivistUnrar"
fi
if [[ -x "$ROOT/Helpers/build/ArchivistRar" ]]; then
  cp "$ROOT/Helpers/build/ArchivistRar" "$DIST/Contents/Helpers/ArchivistRar"
fi
if [[ -f "$ROOT/Helpers/build/rarfiles.lst" ]]; then
  cp "$ROOT/Helpers/build/rarfiles.lst" "$DIST/Contents/Helpers/rarfiles.lst"
fi
if [[ -f "$ROOT/Helpers/build/default.sfx" ]]; then
  cp "$ROOT/Helpers/build/default.sfx" "$DIST/Contents/Helpers/default.sfx"
fi
if [[ -f "$ROOT/Helpers/build/RARLAB-license.txt" ]]; then
  cp "$ROOT/Helpers/build/RARLAB-license.txt" "$DIST/Contents/Resources/RARLAB-license.txt"
fi
if [[ -x /opt/homebrew/bin/7zz && ! -x "$DIST/Contents/Helpers/Archivist7z" ]]; then
  cp /opt/homebrew/bin/7zz "$DIST/Contents/Helpers/Archivist7z"
fi
if [[ -x /opt/homebrew/bin/unrar && ! -x "$DIST/Contents/Helpers/ArchivistUnrar" ]]; then
  cp /opt/homebrew/bin/unrar "$DIST/Contents/Helpers/ArchivistUnrar"
fi
if [[ -x /opt/homebrew/bin/rar && ! -x "$DIST/Contents/Helpers/ArchivistRar" ]]; then
  cp /opt/homebrew/bin/rar "$DIST/Contents/Helpers/ArchivistRar"
fi

/usr/bin/codesign --force --sign - --timestamp=none "$DIST/Contents/Helpers/ArchivistRar" 2>/dev/null || true
/usr/bin/codesign --force --sign - --timestamp=none "$DIST/Contents/Helpers/ArchivistUnrar" 2>/dev/null || true
/usr/bin/codesign --force --sign - --timestamp=none "$DIST/Contents/Helpers/Archivist7z" 2>/dev/null || true
/usr/bin/codesign --force --sign - --entitlements "$ROOT/Resources/Archivist.entitlements" --timestamp=none "$DIST" || true
echo "Packaged $DIST"

# Keep Finder actions in sync when packaging locally.
if [[ "${ARCHIVIST_INSTALL_FINDER:-1}" == "1" ]]; then
  "$ROOT/Scripts/install-finder-integration.sh" "$DIST" || true
fi
