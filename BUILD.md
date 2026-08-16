# Build from source

Use this if you are developing Archivist or cannot use the Apple Silicon disk image. Most people should install from [Releases](https://github.com/MoomenALdahdouh/Archivist/releases) instead.

## Requirements

- macOS 14 or later
- Swift 6 (Xcode or Command Line Tools)
- [Homebrew](https://brew.sh)

```bash
brew install libarchive xz zstd lz4 libb2 sevenzip pkg-config
```

`libarchive` is keg-only. The scripts set `PKG_CONFIG_PATH`.

Optional helpers:

```bash
./Scripts/build-helpers.sh
```

That copies `7zz` when Homebrew has it, and downloads official RARLAB `rar` / `unrar` into `Helpers/build/` (gitignored). Encrypted 7Z/RAR and RAR create need those helpers.

## One-step install

```bash
./Scripts/install.sh
```

Builds a release app, embeds libarchive inside the bundle (so the installed app does not need Homebrew at runtime), copies it to `/Applications`, and registers Finder Quick Actions.

## Commands

```bash
./Scripts/build.sh              # debug
./Scripts/build.sh release
./Scripts/test.sh               # ArchiveTestRunner (no XCTest required)
./Scripts/package-app.sh        # dist/Archivist.app; also installs to /Applications by default
./Scripts/release.sh            # dist/Archivist-<version>.dmg (does not overwrite /Applications)
```

Without full Xcode, `xcodebuild` and XCTest are unavailable. SwiftPM builds `ArchivistApp` and `archivemgr`; `package-app.sh` wraps them as `Archivist.app` and vendors Homebrew dylibs into `Contents/Frameworks/`.

## Layout

- `Sources/ArchiveCore` — engine, security, jobs
- `Sources/ArchiveBackends` — libarchive, 7-Zip, RARLAB helpers, disk images
- `Sources/ArchivistApp` — SwiftUI app
- `Sources/ArchiveCLI` / `Sources/archivemgr` — CLI
- `Sources/ArchiveTestRunner` — tests

Do not put format logic in views.

## Tests

```bash
./Scripts/test.sh
```

Coverage includes format detection, Zip Slip / symlink / bomb checks, CLI exit codes, and round-trip hashes for ZIP, TAR, 7Z, RAR, and GZIP. Extra fixtures: `./Scripts/generate-testdata.sh`.

## Release disk image

```bash
./Scripts/release.sh
```

Produces `dist/Archivist.app` and `dist/Archivist-1.0.0.dmg`. The packaged binaries must not link `/opt/homebrew` — `package-app.sh` fails if they still do.

The public DMG is **ad-hoc signed**, not Developer ID notarized. Users open it with **right-click → Open**. To notarize on a Mac that has a Developer ID certificate:

```bash
export ARCHIVIST_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export ARCHIVIST_NOTARY_PROFILE="archivist"
./Scripts/release.sh
```

Apple Silicon is the supported release architecture. Intel Macs can build from source with Homebrew’s x86_64 libarchive.

GitHub Actions builds the DMG on version tags (`v*`).
