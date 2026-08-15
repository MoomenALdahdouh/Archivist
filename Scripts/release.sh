#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

"$ROOT/Scripts/build-helpers.sh" || true
"$ROOT/Scripts/package-app.sh"

APP="$ROOT/dist/Archivist.app"
STAGE="$ROOT/dist/dmg"
rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "$ROOT/LICENSE" "$STAGE/LICENSE"
cp "$ROOT/README.md" "$STAGE/README.md"

DMG="$ROOT/dist/Archivist-1.0.0.dmg"
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
  echo "To notarize: export ARCHIVIST_SIGN_IDENTITY='Developer ID Application: Name (TEAMID)'"
  echo "and configure notarytool keychain profile ARCHIVIST_NOTARY_PROFILE."
fi

echo "Verify:"
codesign -dv --verbose=4 "$APP" || true
spctl --assess --type execute "$APP" || true
