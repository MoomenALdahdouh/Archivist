#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# A DMG build must not overwrite the machine's /Applications copy.
export ARCHIVIST_INSTALL_FINDER=0

"$ROOT/Scripts/build-helpers.sh"
"$ROOT/Scripts/package-app.sh"

APP="$ROOT/dist/Archivist.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/Resources/Info.plist")"
STAGE="$ROOT/dist/dmg"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/LICENSE" "$STAGE/LICENSE"
cp "$ROOT/Resources/DMG-Read-Me.txt" "$STAGE/Read Me.txt"

DMG="$ROOT/dist/Archivist-${VERSION}.dmg"
rm -f "$DMG"
hdiutil create -volname "Archivist" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
echo "Created $DMG"

# Signing / notarization (requires Developer ID Application identity)
IDENTITY="${ARCHIVIST_SIGN_IDENTITY:-}"
if [[ -n "$IDENTITY" ]]; then
  codesign --force --deep --options runtime --sign "$IDENTITY" --entitlements "$ROOT/Resources/Archivist.entitlements" "$APP"
  xcrun notarytool submit "$DMG" --keychain-profile "${ARCHIVIST_NOTARY_PROFILE:-archivist}" --wait
  xcrun stapler staple "$DMG"
  xcrun stapler staple "$APP"
  echo "Notarized and stapled"
else
  echo "No ARCHIVIST_SIGN_IDENTITY set. Ad-hoc signed package only."
  echo "The first time you open Archivist, right-click the app and choose Open."
  echo "To notarize: export ARCHIVIST_SIGN_IDENTITY='Developer ID Application: Name (TEAMID)'"
  echo "and configure notarytool keychain profile ARCHIVIST_NOTARY_PROFILE."
fi

echo "Verify:"
codesign -dv --verbose=4 "$APP" || true
spctl --assess --type execute "$APP" || true
