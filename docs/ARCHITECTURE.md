# Architecture

Archivist is a native macOS archive manager. The app and CLI share one engine.

## Layers

1. **ArchivistApp** — SwiftUI + AppKit. No archive format logic.
2. **ArchiveCLI / archivemgr** — command-line front end.
3. **ArchiveCore** — models, format detection, security, jobs, progress, settings.
4. **ArchiveBackends** — libarchive, 7-Zip helper, UnRAR/RAR helpers, hdiutil.
5. **CLibArchive** — clang module over libarchive. Release builds vendor the dylib into `Archivist.app/Contents/Frameworks/`.

## Data flow

Finder / Dock / Open panel / CLI → `ArchiveEngine` (actor) → `BackendRegistry` → backend → `ExtractionGuard` → filesystem.

Jobs are queued in `JobManager`. Progress is measured in bytes whenever totals are known; otherwise the UI shows an indeterminate indicator.

## Security

Every extract path is normalized. Absolute paths, `..`, null bytes, and symlink escapes are rejected. Decompression-bomb ratios and entry-count limits are enforced before extract.

## Isolation

7-Zip (LGPL) and RARLAB `rar`/`unrar` run as replaceable helper processes in `Contents/Helpers/`, not linked into the app.
