#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if command -v brew >/dev/null 2>&1; then
  LA_PREFIX="$(brew --prefix libarchive 2>/dev/null || true)"
  if [[ -n "${LA_PREFIX}" ]]; then
    export PKG_CONFIG_PATH="${LA_PREFIX}/lib/pkgconfig:${PKG_CONFIG_PATH:-}"
  fi
fi
export PKG_CONFIG_PATH="/opt/homebrew/opt/libarchive/lib/pkgconfig:/usr/local/opt/libarchive/lib/pkgconfig:${PKG_CONFIG_PATH:-}"

swift build -c release --product ArchivistApp
swift build -c release --product archivemgr

if [[ ! -x "$ROOT/Helpers/build/ArchivistRar" || ! -x "$ROOT/Helpers/build/ArchivistUnrar" ]]; then
  "$ROOT/Scripts/build-helpers.sh"
fi
/usr/bin/swift "$ROOT/Scripts/generate-icons.swift" "$ROOT"

BIN_APP="$(swift build -c release --show-bin-path)/ArchivistApp"
BIN_CLI="$(swift build -c release --show-bin-path)/archivemgr"
DIST="$ROOT/dist/Archivist.app"
rm -rf "$ROOT/dist"
mkdir -p "$DIST/Contents/MacOS" "$DIST/Contents/Helpers" "$DIST/Contents/Resources" "$DIST/Contents/Library/Services" "$DIST/Contents/Frameworks"

cp "$BIN_APP" "$DIST/Contents/MacOS/Archivist"
cp "$BIN_CLI" "$DIST/Contents/MacOS/archivemgr"
cp "$ROOT/Resources/Info.plist" "$DIST/Contents/Info.plist"
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$DIST/Contents/Resources/AppIcon.icns"
fi
if [[ -f "$ROOT/Resources/RAR.icns" ]]; then
  cp "$ROOT/Resources/RAR.icns" "$DIST/Contents/Resources/RAR.icns"
fi
if [[ -f "$ROOT/Resources/Credits.rtf" ]]; then
  cp "$ROOT/Resources/Credits.rtf" "$DIST/Contents/Resources/Credits.rtf"
fi
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
# Keep RAR list/sfx next to Resources, not Helpers — otherwise codesign treats them as nested code.
if [[ -f "$ROOT/Helpers/build/rarfiles.lst" ]]; then
  cp "$ROOT/Helpers/build/rarfiles.lst" "$DIST/Contents/Resources/rarfiles.lst"
fi
if [[ -f "$ROOT/Helpers/build/default.sfx" ]]; then
  cp "$ROOT/Helpers/build/default.sfx" "$DIST/Contents/Resources/default.sfx"
fi
if [[ -f "$ROOT/Helpers/build/RARLAB-license.txt" ]]; then
  cp "$ROOT/Helpers/build/RARLAB-license.txt" "$DIST/Contents/Resources/RARLAB-license.txt"
fi
if command -v brew >/dev/null 2>&1; then
  SEVENZIP_BIN="$(brew --prefix sevenzip 2>/dev/null)/bin/7zz"
  if [[ -x "$SEVENZIP_BIN" && ! -x "$DIST/Contents/Helpers/Archivist7z" ]]; then
    cp "$SEVENZIP_BIN" "$DIST/Contents/Helpers/Archivist7z"
  fi
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

FRAMEWORKS="$DIST/Contents/Frameworks"

copy_bundled_lib() {
  local name="$1"
  local formula="${2:-}"
  local src=""
  local candidate
  local prefixes=()
  if command -v brew >/dev/null 2>&1 && [[ -n "$formula" ]]; then
    prefixes+=("$(brew --prefix "$formula" 2>/dev/null || true)")
  fi
  prefixes+=(/opt/homebrew/opt/"$formula" /usr/local/opt/"$formula")
  for prefix in "${prefixes[@]}"; do
    [[ -n "$prefix" && -f "$prefix/lib/$name" ]] || continue
    src="$prefix/lib/$name"
    break
  done
  if [[ -z "$src" ]]; then
    echo "warning: $name not found; the packaged app may not run without Homebrew" >&2
    return 0
  fi
  cp "$src" "$FRAMEWORKS/$name"
  chmod u+w "$FRAMEWORKS/$name"
  install_name_tool -id "@rpath/$name" "$FRAMEWORKS/$name"
  echo "Bundled $src"
}

rewrite_homebrew_deps() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  chmod u+w "$file"
  local dep base
  otool -L "$file" | awk '/\/opt\/homebrew\/|\/usr\/local\/opt\// {print $1}' | while read -r dep; do
    [[ -z "$dep" ]] && continue
    base="${dep##*/}"
    if [[ -f "$FRAMEWORKS/$base" ]]; then
      install_name_tool -change "$dep" "@rpath/$base" "$file"
    fi
  done
  local rpath
  otool -l "$file" | awk '
    /cmd LC_RPATH/ { in_rpath=1; next }
    in_rpath && /path / { print $2; in_rpath=0 }
  ' | while read -r rpath; do
    case "$rpath" in
      /opt/homebrew/*|/usr/local/opt/*)
        install_name_tool -delete_rpath "$rpath" "$file" 2>/dev/null || true
        ;;
    esac
  done
}

copy_bundled_lib libarchive.13.dylib libarchive
copy_bundled_lib liblzma.5.dylib xz
copy_bundled_lib libzstd.1.dylib zstd
copy_bundled_lib liblz4.1.dylib lz4
copy_bundled_lib libb2.1.dylib libb2

for lib in "$FRAMEWORKS"/*.dylib(N); do
  rewrite_homebrew_deps "$lib"
done

for bin in Archivist archivemgr; do
  rewrite_homebrew_deps "$DIST/Contents/MacOS/$bin"
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$DIST/Contents/MacOS/$bin" 2>/dev/null || true
done

still_homebrew() {
  otool -L "$1" | grep -E '/opt/homebrew/|/usr/local/opt/' >/dev/null
}

if still_homebrew "$DIST/Contents/MacOS/Archivist" || still_homebrew "$DIST/Contents/MacOS/archivemgr"; then
  echo "error: packaged binaries still link Homebrew libraries:" >&2
  otool -L "$DIST/Contents/MacOS/Archivist" >&2
  otool -L "$DIST/Contents/MacOS/archivemgr" >&2
  exit 1
fi
if [[ -f "$FRAMEWORKS/libarchive.13.dylib" ]] && still_homebrew "$FRAMEWORKS/libarchive.13.dylib"; then
  echo "error: bundled libarchive still links Homebrew libraries:" >&2
  otool -L "$FRAMEWORKS/libarchive.13.dylib" >&2
  exit 1
fi

sign_adhoc() {
  local path="$1"
  [[ -e "$path" ]] || return 0
  /usr/bin/codesign --force --sign - --timestamp=none "$path"
}

xattr -cr "$DIST" 2>/dev/null || true
for lib in "$FRAMEWORKS"/*.dylib(N); do
  sign_adhoc "$lib"
done
sign_adhoc "$DIST/Contents/Helpers/ArchivistRar"
sign_adhoc "$DIST/Contents/Helpers/ArchivistUnrar"
sign_adhoc "$DIST/Contents/Helpers/Archivist7z"
sign_adhoc "$DIST/Contents/MacOS/archivemgr"
/usr/bin/codesign --force --sign - --entitlements "$ROOT/Resources/Archivist.entitlements" --timestamp=none "$DIST"
/usr/bin/codesign --verify --verbose=2 "$DIST"
echo "Packaged $DIST"

# Keep Finder actions in sync when packaging locally.
if [[ "${ARCHIVIST_INSTALL_FINDER:-1}" == "1" ]]; then
  "$ROOT/Scripts/install-finder-integration.sh" "$DIST" || true
fi
