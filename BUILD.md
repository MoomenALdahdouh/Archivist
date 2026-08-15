# Build

## Requirements

- macOS 14+
- Swift 6 Command Line Tools or Xcode
- Homebrew `libarchive` (keg-only)

```bash
brew install libarchive xz zstd lz4 brotli
```

Optional helpers:

```bash
brew install sevenzip   # 7zz — encrypted 7Z, WIM, MSI, split volumes
./Scripts/build-helpers.sh   # downloads official RARLAB rar + unrar into Helpers/build
```

## Commands

```bash
./Scripts/build.sh
./Scripts/build.sh release
./Scripts/test.sh
./Scripts/package-app.sh
./Scripts/release.sh
```

`PKG_CONFIG_PATH` must include Homebrew libarchive. The scripts set this.

Without full Xcode, `xcodebuild` is unavailable. SwiftPM builds `ArchivistApp` and `archivemgr`; `package-app.sh` wraps them as `Archivist.app`.
