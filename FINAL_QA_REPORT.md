# Final QA report

Date: 2026-08-15
Build host: macOS 26.5.2, Swift 6.3.3, Command Line Tools (no full Xcode)

| Feature | Status | Test | Result | Known limitation |
| --- | --- | --- | --- | --- |
| ZIP create/extract round-trip | Implemented | ArchiveTestRunner zip round trip | Pass (SHA-256) | |
| TAR create/extract | Implemented | tar round trip | Pass | |
| TAR.GZ create/extract | Implemented | tar.gz round trip | Pass | |
| 7Z create/extract (unencrypted) | Implemented | 7z round trip | Pass | Encrypted 7Z needs 7zz |
| GZIP create/extract | Implemented | gzip round trip | Pass | Extract via /usr/bin/gzip |
| Unicode filenames | Implemented | unicode round trip | Pass | Arabic, Turkish, CJK, spaces |
| Format magic bytes | Implemented | zip/rar/7z/gzip magic | Pass | |
| Zip Slip rejection | Implemented | path security tests | Pass | |
| Symlink escape | Implemented | security tests | Pass | |
| Decompression bomb | Implemented | bomb ratio test | Pass | |
| CLI help / unknown / parse | Implemented | CLI tests | Pass | Exit codes 0 and 2 |
| Job completion | Implemented | job manager test | Pass | |
| App build | Implemented | swift build ArchivistApp | Pass | |
| CLI build | Implemented | swift build archivemgr | Pass | |
| RAR extract encrypted | Helper-ready | not run (no unrar binary) | Untested | Helper missing |
| 7Z encrypted / split | Helper-ready | not run (no 7zz) | Untested | brew sevenzip not installed |
| Finder Services | Declared in Info.plist | not run (needs packaged app + Finder) | Untested | |
| Notarization | Scripted | not run | Untested | No Developer ID |
| XCUITest | Not run | n/a | Untested | No Xcode.app |
| 1GB+ files | Streaming I/O present | not run (size) | Untested | Generate locally |

Core create/extract for ZIP, 7Z, TAR, TAR.GZ, GZIP was executed on this machine. Do not read “Implemented” in the UI as “Finder-tested” unless this table says Pass.
