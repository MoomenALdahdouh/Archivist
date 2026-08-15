# Release

```bash
./Scripts/release.sh
```

Produces `dist/Archivist.app` and `dist/Archivist-1.0.0.dmg` (app + Applications shortcut + license).

## Signing / notarization

This machine has Apple Development identities, not Developer ID Application. Live notarization is therefore not run.

To notarize on a Developer ID Mac:

```bash
export ARCHIVIST_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export ARCHIVIST_NOTARY_PROFILE="archivist"
xcrun notarytool store-credentials archivist --apple-id ... --team-id ... --password ...
./Scripts/release.sh
```

The script signs with Hardened Runtime entitlements, submits the DMG, staples, and runs `codesign`/`spctl` verification.

Universal 2: SwiftPM on Apple Silicon builds arm64. Cross-compile x86_64 with:

```bash
swift build -c release --arch arm64 --arch x86_64
```

when both slices of libarchive/helpers exist. If a helper is arm64-only, document that limitation in KNOWN_LIMITATIONS.md.
