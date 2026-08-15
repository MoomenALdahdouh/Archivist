# Development

Open the folder in Cursor or generate an Xcode project later with XcodeGen if Xcode is installed.

Layout:

- `Sources/ArchiveCore` — engine, security, jobs
- `Sources/ArchiveBackends` — libarchive + helpers
- `Sources/ArchivistApp` — SwiftUI UI
- `Sources/archivemgr` / `Sources/ArchiveCLI` — CLI
- `Sources/ArchiveTestRunner` — tests (Swift Testing/XCTest are not present in Command Line Tools-only installs)

Do not put format logic in views. After each phase: `./Scripts/build.sh` and `./Scripts/test.sh`.
