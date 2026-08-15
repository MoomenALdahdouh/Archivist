# Architecture

Archivist is a native macOS archive manager. UI and CLI share one engine.

## Layers

1. **ArchivistApp** — SwiftUI + AppKit. No archive format logic.
2. **ArchiveCLI / archivemgr** — command-line front end.
3. **ArchiveCore** — models, format detection, security, jobs, progress, settings.
4. **ArchiveBackends** — libarchive, 7-Zip helper, UnRAR helper, hdiutil.
5. **CLibArchive** — clang module over Homebrew libarchive.

## Data flow

Finder / Dock / Open panel / CLI → `ArchiveEngine` (actor) → `BackendRegistry` → backend → `ExtractionGuard` → filesystem.

Jobs are queued in `JobManager`. Progress is measured in bytes whenever totals are known; otherwise the UI shows an indeterminate indicator.

## Security

Every extract path is normalized. Absolute paths, `..`, null bytes, and symlink escapes are rejected. Decompression-bomb ratios and entry-count limits are enforced before extract.

## Isolation

7-Zip (LGPL) and UnRAR run as replaceable helper processes, not linked into the app. RAR creation is not implemented.
