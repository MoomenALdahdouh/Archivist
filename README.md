# Archivist

A native macOS archive manager for listing, extracting, creating, and testing archives. Archivist is designed as a professional utility: streaming I/O, real progress, cancellation, Zip Slip protection, and honest format capabilities.

It is **not** WinRAR and does not use WinRAR source or branding. RAR create and extract use the official RARLAB command-line helpers.

## Features

- Browse archive contents without extracting
- Extract all or selected entries with overwrite policies and metadata preservation
- Create RAR, ZIP, 7Z, TAR and compressed TAR/single-file formats
- Extract and create RAR/RAR5 via bundled RARLAB helpers
- Password-protected RAR, ZIP, and 7Z
- Job queue with real byte progress, speed, and ETA
- Finder Services, file associations, Dock drag-and-drop
- `archivemgr` CLI sharing the same engine
- Offline, no telemetry

## Requirements

- macOS 14 or later
- Swift 6 toolchain (Xcode or Command Line Tools)
- Homebrew `libarchive` (and typically `xz`, `zstd`, `lz4`, `brotli`)

## Build

See [BUILD.md](BUILD.md). Quick start:

```bash
./scripts/build.sh
./scripts/package-app.sh
```

## CLI

```bash
archivemgr list archive.zip
archivemgr extract archive.zip ./output
archivemgr create ./folder archive.rar
archivemgr test archive.rar
```

See [CLI.md](CLI.md) for exit codes.

## License

MIT for Archivist source. Third-party terms: [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md) and [DEPENDENCY_LICENSE_AUDIT.md](DEPENDENCY_LICENSE_AUDIT.md).
